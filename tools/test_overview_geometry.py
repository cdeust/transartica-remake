"""MIT. Measured static-plan inventory regression; private source required."""
import json
import unittest
from export_overview_geometry import SOURCE, extract


def reconstruct(vectors):
    """Source: exact inclusive source vector endpoints, compared to input pixels."""
    result = set()
    for x, y, end_x, end_y in vectors:
        dx = (end_x > x) - (end_x < x)
        dy = (end_y > y) - (end_y < y)
        result.add((x, y))
        while (x, y) != (end_x, end_y):
            x, y = x + dx, y + dy
            result.add((x, y))
    return result


class StaticPlanGeometry(unittest.TestCase):
    def test_vector_inventory(self):
        source=json.loads(SOURCE.read_bytes())
        rows=[[i for i,n in row for _ in range(n)] for row in source['rows']]
        result=extract()
        for key,index in [('routes',10),('compartments',11)]:
            reconstructed=reconstruct(result[key])
            expected={(x,y) for y,row in enumerate(rows) for x,i in enumerate(row) if i==index}
            self.assertEqual(reconstructed,expected,'No added/omitted staticplan route geometry')
        self.assertEqual(len(result['towns']),45)
        for x,y,w,h in result['towns']:
            self.assertTrue(all(rows[py][px]==14 for py in range(y,y+h) for px in range(x,x+w)))
        self.assertEqual(len(result['dots']),206)
        self.assertEqual(len(result['symbols']),10)
        self.assertFalse(any(key in result for key in ['palette','rows','pixels','map_bytes']))


if __name__=='__main__':unittest.main()
