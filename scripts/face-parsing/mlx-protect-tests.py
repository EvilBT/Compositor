"""Geometry/semantic regressions for the offline optimizer."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
import numpy as np

spec=importlib.util.spec_from_file_location('protect',Path(__file__).with_name('mlx-protect.py'))
protect=importlib.util.module_from_spec(spec);spec.loader.exec_module(protect)

class ProtectionTests(unittest.TestCase):
    def predictions(self, masks):
        return [(text,SimpleNamespace(masks=np.asarray(masks.get(text,[]),dtype=np.uint8).reshape(-1,60,60)))
                for text in ['rhinestones','glitter','pearls','glitter makeup']]

    def test_mostly_external_object_is_rejected_before_clipping(self):
        skin=np.zeros((60,60),bool);skin[10:30,10:30]=True
        mask=np.zeros_like(skin);mask[5:35,5:35]=True
        union,confirmed,accepted,rejected=protect.collect(self.predictions({'pearls':[mask]}),skin,[0,0,60,60],100)
        self.assertEqual(accepted,0);self.assertEqual(rejected,1);self.assertFalse(union.any())

    def test_single_phrase_is_candidate_but_not_confirmed(self):
        skin=np.ones((60,60),bool);mask=np.zeros_like(skin);mask[10:15,10:15]=True
        union,confirmed,_,_=protect.collect(self.predictions({'glitter':[mask]}),skin,[0,0,60,60],100)
        self.assertTrue(union.any());self.assertFalse(confirmed.any())

    def test_agreement_stays_inside_skin(self):
        skin=np.ones((60,60),bool);skin[10,10]=False
        mask=np.zeros_like(skin);mask[10:15,10:15]=True
        union,confirmed,_,_=protect.collect(self.predictions({'rhinestones':[mask],'pearls':[mask]}),skin,[0,0,60,60],100)
        self.assertTrue(confirmed.any());self.assertFalse(confirmed[~skin].any());self.assertTrue(np.array_equal(confirmed,union))

    def test_large_skin_prediction_is_not_an_accessory(self):
        skin=np.ones((60,60),bool)
        union,_,accepted,_=protect.collect(self.predictions({'glitter':[skin]}),skin,[0,0,60,60],100)
        self.assertEqual(accepted,0);self.assertFalse(union.any())

    def test_rois_clamp_at_image_boundary(self):
        points={k:[.08,.1] for k in ['eyeLeft','eyeRight','cheekLeft','cheekRight','mouthCenter']}
        face={'boundingBox':{'origin':[0,0],'size':[.3,.3]},'landmarks':points}
        rois,guard,_=protect.regions(face,[0,0,100,100],(100,100),(100,100))
        for x0,y0,x1,y1 in rois.values():
            self.assertGreaterEqual(x0,0);self.assertGreaterEqual(y0,0)
            self.assertLessEqual(x1,100);self.assertLessEqual(y1,100)
            self.assertGreater(x1,x0);self.assertGreater(y1,y0)
        self.assertEqual(int(guard.sum()),900)

if __name__=='__main__':unittest.main()
