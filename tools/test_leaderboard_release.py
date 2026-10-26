import io
import json
import unittest
from urllib.error import HTTPError, URLError
from check_leaderboard_release import check_release


class ReleaseGateTests(unittest.TestCase):
    def setUp(self):
        self.manifest={'content_sha256':'a'*64,'game_version':'1.4.1-dev','content_version':10}
        self.config={'enabled':True,'project_url':'https://example.test','publishable_key':'PUBLIC_TEST'}

    def test_accepted_identity_is_checked_without_player_session(self):
        def opener(request,timeout):
            self.assertEqual(request.get_method(),'GET')
            self.assertIn('rules_hash='+'a'*64,request.full_url)
            self.assertIn('game_version=1.4.1-dev',request.full_url)
            self.assertIn('content_version=10',request.full_url)
            self.assertFalse(request.has_header('Authorization'))
            return io.BytesIO(b'{"accepting":true}')
        self.assertIn('CHECK_OK',check_release(self.manifest,self.config,opener))

    def test_unregistered_release_stops_publication(self):
        def opener(*args,**kwargs): raise HTTPError('https://example.test',409,'Conflict',{},None)
        with self.assertRaisesRegex(ValueError,'not approved'):
            check_release(self.manifest,self.config,opener)

    def test_outage_or_false_response_stops_publication(self):
        def offline(*args,**kwargs): raise URLError('offline')
        for opener in [offline,lambda *args,**kwargs: io.BytesIO(b'{"accepting":false}'),lambda *args,**kwargs: io.BytesIO(b'{"accepting":"true"}')]:
            with self.assertRaises(ValueError): check_release(self.manifest,self.config,opener)

    def test_intentionally_disabled_leaderboard_needs_no_network(self):
        self.config['enabled']=False
        self.assertIn('SKIPPED',check_release(self.manifest,self.config,lambda *args,**kwargs: self.fail('must not request')))


if __name__ == '__main__': unittest.main()
