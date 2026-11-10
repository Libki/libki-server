import copy
import time
import unittest
from adapter.libki_adapter import validate_job

class AdapterQuantities(unittest.TestCase):
    def job(self):
        return dict(destination='main', print_mode='color', release_code='MP-ABCD-2345',
                    phone_number='2025550147', pages=100, copies=99, file_count=1,
                    expires_at=int(time.time())+3600)

    def test_old_job(self):
        self.assertEqual(validate_job(self.job())['color'], 'main-color')

    def test_large_bundle_and_genealogy(self):
        job = self.job()
        job.update(destination='genealogy', pages=9900, copies=1,
                   document_quantities=[dict(document=1,pages=100,copies=99,printed_pages=9900)])
        self.assertEqual(validate_job(job)['color'], 'genealogy-color')
        for key, value in [('copies',2), ('pages',9999), ('file_count',2)]:
            invalid=copy.deepcopy(job); invalid[key]=value
            with self.assertRaises(RuntimeError): validate_job(invalid)
        job['document_quantities'][0]['pages']=101
        with self.assertRaises(RuntimeError): validate_job(job)

    def test_large_legacy_rejected(self):
        job=self.job(); job['pages']=501
        with self.assertRaises(RuntimeError): validate_job(job)
