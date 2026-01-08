from django.test import TestCase, override_settings
from django.urls import reverse
from django.core import mail
import json


class EmailNotificationTests(TestCase):
    def setUp(self):
        self.url = reverse('send_notification')
        self.payload = {
            'title': 'Test Title',
            'summary': 'A short summary of the item.',
            'author_name': 'Jane Developer',
            'created_at': '2026-01-08T12:00:00Z',
            'url': 'https://example.com/item/1',
        }

    @override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend', NOTIFICATION_EMAILS=['ananab.tilps@gmail.com'])
    def test_send_notification_sends_email(self):
        resp = self.client.post(self.url, data=json.dumps(self.payload), content_type='application/json')
        self.assertEqual(resp.status_code, 202)
        self.assertEqual(len(mail.outbox), 1)
        msg = mail.outbox[0]
        self.assertIn(self.payload['title'], msg.subject)
        self.assertIn(self.payload['summary'], msg.body)
        self.assertEqual(msg.to, ['ananab.tilps@gmail.com'])

    def test_bad_method(self):
        resp = self.client.get(self.url)
        self.assertEqual(resp.status_code, 400)

    def test_missing_fields(self):
        bad = dict(self.payload)
        del bad['title']
        resp = self.client.post(self.url, data=json.dumps(bad), content_type='application/json')
        self.assertEqual(resp.status_code, 400)
