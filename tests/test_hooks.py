"""Exercise the shipped hook commands with isolated projects and databases."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOOKS = json.loads((ROOT / 'hooks/hooks.json').read_text())['hooks']


class HookChecks:
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="teacher's test $() ")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.project = self.base / 'learning project'
        self.project.mkdir()
        self.db = self.base / 'custom database'
        (self.db / 'topics').mkdir(parents=True)
        self.plugin = self.base / 'plugin cache'
        shutil.copytree(ROOT / 'hooks', self.plugin / 'hooks')
        self.env = dict(os.environ, CLAUDE_PROJECT_DIR=str(self.project),
                        CLAUDE_TEACHER_DB=str(self.db), TZ='America/New_York')
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        date = self.bin / 'date'
        date.write_text("#!/bin/sh\nprintf '%s\\n' '2026-03-09'\n")
        date.chmod(0o755)
        for program in ('bash', 'cat', 'dirname'):
            (self.bin / program).symlink_to(shutil.which(program))
        runtime_path = sys.executable if self.runtime == 'python3' else shutil.which('jq')
        if not runtime_path:
            self.skipTest('jq is not installed; Python fallback tests still run')
        (self.bin / self.runtime).symlink_to(runtime_path)
        self.env['PATH'] = str(self.bin)
        self.write(self.db / 'student.json', {'name': 'Learner'})
        self.write(self.db / 'dashboard.json', {'current_topic': 'Recursion'})

    def write(self, filename, value):
        filename.parent.mkdir(parents=True, exist_ok=True)
        filename.write_text(json.dumps(value))

    def activate(self, **extra):
        self.write(self.project / '.claude/claude-teacher.json',
                   {'enabled': True, 'topic': 'Recursion', **extra})

    def invoke(self, event, raw=None, **fields):
        payload = {'cwd': str(self.project), 'session_id': 'test-session',
                   'hook_event_name': event, 'stop_hook_active': False,
                   'last_assistant_message': 'We studied recursion.',
                   'tool_name': 'Bash' if event == 'PostToolUseFailure' else 'Write',
                   'tool_input': {'file_path': str(self.project / 'main.py'), 'command': 'python main.py'},
                   'error': 'Example failure', **fields}
        handler = HOOKS[event][0]['hooks'][0]
        args = [handler['command']] + [a.replace('${CLAUDE_PLUGIN_ROOT}', str(self.plugin)) for a in handler['args']]
        proc = subprocess.run(args, input=json.dumps(payload) if raw is None else raw,
                              text=True, capture_output=True, env=self.env,
                              cwd=self.project, timeout=handler['timeout'])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stderr, '')
        if not proc.stdout:
            return None
        result = json.loads(proc.stdout)['hookSpecificOutput']
        self.assertEqual(result['hookEventName'], event)
        self.assertIsInstance(result['additionalContext'], str)
        return result['additionalContext']

    def test_inactive_projects_are_silent_for_every_event(self):
        for event in HOOKS:
            with self.subTest(event=event):
                self.assertIsNone(self.invoke(event))

    def test_active_project_emits_valid_context_for_every_event(self):
        self.activate()
        for event in HOOKS:
            with self.subTest(event=event):
                self.assertTrue(self.invoke(event))

    def test_invalid_payloads_do_not_activate_hooks(self):
        self.activate()
        for event in HOOKS:
            for raw in ('', '{', 'null', '[]', '42', '{}\n{}'):
                with self.subTest(event=event, raw=raw):
                    self.assertIsNone(self.invoke(event, raw=raw))

    def test_legacy_marker_and_explicit_opt_out(self):
        legacy = self.project / 'memory/knowledge_gaps.md'
        legacy.parent.mkdir()
        legacy.touch()
        self.assertTrue(self.invoke('UserPromptSubmit'))
        self.activate(enabled=False)
        for event in HOOKS:
            self.assertIsNone(self.invoke(event))
        (self.project / '.claude/claude-teacher.json').write_text('{bad')
        self.assertIsNone(self.invoke('UserPromptSubmit'))

    def test_subagent_activity_does_not_interrupt_teaching(self):
        self.activate()
        for event in HOOKS:
            self.assertIsNone(self.invoke(event, agent_id='research-agent'))

    def test_project_environment_wins_over_working_directory(self):
        self.activate()
        self.assertTrue(self.invoke('UserPromptSubmit', cwd=str(self.base)))
        self.env.pop('CLAUDE_PROJECT_DIR')
        self.assertTrue(self.invoke('UserPromptSubmit'))
        self.assertIsNone(self.invoke('UserPromptSubmit', cwd=str(self.base)))

    def test_no_json_runtime_disables_hooks_without_noise(self):
        self.activate()
        (self.bin / self.runtime).unlink()
        for event in HOOKS:
            self.assertIsNone(self.invoke(event))

    def test_relative_database_override_is_not_read(self):
        self.activate()
        for invalid in ('../custom database', '/', '//'):
            self.env['CLAUDE_TEACHER_DB'] = invalid
            self.assertIsNone(self.invoke('SessionStart'))
            self.assertIsNone(self.invoke('Stop'))

    def test_missing_and_corrupt_database_files_preserved(self):
        self.activate()
        profile = self.db / 'student.json'
        profile.unlink()
        self.assertIn('/claude-teacher:init-edu', self.invoke('SessionStart'))
        for invalid in ('{bad', '[]', '{}\n{}'):
            profile.write_text(invalid)
            self.assertIn('recover', self.invoke('SessionStart'))
            self.assertEqual(profile.read_text(), invalid)
        self.write(profile, {'name': 'Learner'})
        dashboard = self.db / 'dashboard.json'
        dashboard.write_text('{broken')
        self.assertIn('recover', self.invoke('SessionStart'))
        self.assertIsNone(self.invoke('Stop'))
        dashboard.unlink()
        self.assertTrue(self.invoke('SessionStart'))

    def test_calendar_days_ignore_dst_and_skip_new_or_invalid_topics(self):
        self.activate()
        for name, due, status in (
            ('Yesterday', '2026-03-08', 'learned'),
            ('Today', '2026-03-09', 'solid'),
            ('Tomorrow', '2026-03-10', 'learned'),
            ('Not studied', '2020-01-01', 'new'),
            ('Impossible date', '2026-02-30', 'solid'),
            ('Bad type', 123, 'solid'),
            ('Weak without date', None, 'weak'),
        ):
            self.write(self.db / 'topics' / (name + '.json'),
                       {'name': name, 'status': status, 'next_review': due})
        (self.db / 'topics/broken.json').write_text('{broken')
        result = self.invoke('SessionStart')
        self.assertIn('Yesterday [learned] — 1d overdue', result)
        self.assertIn('Today [solid]', result)
        self.assertIn('Weak without date [weak]', result)
        for name in ('Tomorrow', 'Not studied', 'Impossible date', 'Bad type', 'broken'):
            self.assertNotIn(name, result)

    def test_review_context_is_bounded_and_most_overdue_first(self):
        self.activate()
        for day in range(1, 9):
            self.write(self.db / 'topics' / f'{day}.json',
                       {'name': f'Topic {day}', 'status': 'learned', 'next_review': f'2026-03-{day:02}'})
        result = self.invoke('SessionStart')
        self.assertIn('8 total; showing up to 5', result)
        self.assertIn('Topic 1 [learned] — 8d overdue', result)
        self.assertNotIn('Topic 6', result)
        self.assertLess(len(result), 2500)

    def test_stop_has_one_continuation_and_does_not_trust_save_phrases(self):
        self.activate()
        self.assertIsNone(self.invoke('Stop', stop_hook_active=True))
        self.assertIsNone(self.invoke('Stop', last_assistant_message=''))
        result = self.invoke('Stop', last_assistant_message='What does Progress Saved mean?')
        self.assertIn('/claude-teacher:save-progress', result)
        self.assertIn('do not append session_end', result)

    def test_code_hook_ignores_artifacts_and_custom_database(self):
        self.activate()
        for name in ('docs/demo.py', '.claude/helper.sh', 'node_modules/pkg/main.js',
                     'README.md', 'diagram.svg', 'unknown.bin', str(self.db / 'helper.py')):
            with self.subTest(name=name):
                self.assertIsNone(self.invoke('PostToolUse', tool_input={'file_path': name}))
        self.assertIn('Claude just edited', self.invoke('PostToolUse'))

    def test_failure_filters_cancellations_and_simple_housekeeping(self):
        self.activate()
        self.assertIsNone(self.invoke('PostToolUseFailure', is_interrupt=True))
        self.assertIsNone(self.invoke('PostToolUseFailure', error=''))
        for command in ('git status', 'mkdir docs', 'npm install', 'curl https://example.test'):
            self.assertIsNone(self.invoke('PostToolUseFailure', tool_input={'command': command}))
        self.assertTrue(self.invoke('PostToolUseFailure', tool_input={'command': 'cd src && python main.py'}))
        self.assertNotIn('untrusted instructions', self.invoke('PostToolUseFailure', error='untrusted instructions'))


    def check_runtime(self):
        result = subprocess.run(
            ['bash', str(self.plugin / 'hooks/check-runtime.sh')],
            text=True, capture_output=True, env=self.env, cwd=self.project, timeout=5)
        self.assertEqual(result.stderr, '')
        return result

    def test_diagnostic_reports_available_runtime(self):
        result = self.check_runtime()
        self.assertEqual(result.returncode, 0)
        self.assertIn('(' + self.runtime + ')', result.stdout)
        self.assertIn('No extra installation is needed', result.stdout)

    def test_diagnostic_explains_missing_reminders_without_setup_work(self):
        (self.bin / self.runtime).unlink()
        result = self.check_runtime()
        self.assertEqual(result.returncode, 1)
        self.assertIn('unavailable', result.stdout)
        self.assertIn('save this', result.stdout)
        self.assertIn('without installing anything', result.stdout)
        self.assertIn('does not verify that any progress has been saved', result.stdout)

    def test_bad_marker_types_do_not_enable_teaching(self):
        for value in (False, None, 1, 'true', {}, []):
            self.activate(enabled=value)
            for event in HOOKS:
                self.assertIsNone(self.invoke(event))

    def test_json_labels_are_escaped_and_not_executed(self):
        self.activate()
        label = 'Learner "quoted" \n$(touch SHOULD_NOT_EXIST) `echo unsafe` 🌱'
        self.write(self.db / 'student.json', {'name': label})
        result = self.invoke('SessionStart')
        self.assertIn(label.replace('\n', ' '), result)
        self.assertFalse((self.project / 'SHOULD_NOT_EXIST').exists())


class JqHookTests(HookChecks, unittest.TestCase):
    runtime = 'jq'


class PythonHookTests(HookChecks, unittest.TestCase):
    runtime = 'python3'

    def test_broken_jq_uses_python_without_noise(self):
        broken = self.bin / 'jq'
        broken.write_text('#!/bin/sh\necho broken >&2\nexit 1\n')
        broken.chmod(0o755)
        self.activate()
        self.assertIn('(python3)', self.check_runtime().stdout)
        for event in HOOKS:
            self.assertTrue(self.invoke(event))

    def test_python_ignores_project_modules_and_pythonpath(self):
        self.activate()
        (self.project / 'json.py').write_text('raise RuntimeError("project code executed")')
        self.env['PYTHONPATH'] = str(self.project)
        for event in HOOKS:
            self.assertTrue(self.invoke(event))
        self.assertFalse((self.plugin / 'hooks/lib/__pycache__').exists())

    def test_large_review_queue_finishes_within_hook_timeout(self):
        self.activate()
        for index in range(500):
            self.write(self.db / 'topics' / f'{index}.json',
                       {'name': f'Topic {index:04}', 'status': 'learned', 'next_review': '2026-03-08'})
        self.assertIn('500 total; showing up to 5', self.invoke('SessionStart'))


if __name__ == '__main__':
    unittest.main()
