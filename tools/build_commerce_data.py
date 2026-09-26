"""Build the private runtime commerce table used by game/scripts/city_trade.gd.

Inputs (private, derived from glieu.alis and table.alis; tasks/evidence/city-scripts.md):
  reference-private/city-scripts/glieu-commerce.json  prices and accepted wagons per city
  reference-private/city-scripts/stock-init.json      TABLE 0x75d..0xf0a stock formulas
Output (private): reference-private/commerce.json. Never publish it with MIT code.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'reference-private/city-scripts'
# glieu local slots: 0x20/0x58 = L0x14/L0x3a (wagon a), 0x21/0x60 = L0x15/L0x3c
# (wagon b), 0x54/0x56 = L0x36/L0x38 (buy/sell price). The JSON keys are decimal.
SLOTS = {'wagon_a': '20', 'cap_a': '58', 'wagon_b': '21', 'cap_b': '60', 'buy': '54', 'sell': '56'}


def _offer(record):
    return {name: int(record.get(slot, 0)) for name, slot in SLOTS.items()}


def build():
    source = json.loads((SOURCE / 'glieu-commerce.json').read_text())
    prices = source['data']
    stock = json.loads((SOURCE / 'stock-init.json').read_text())['stock']
    goods_names = list(prices['goods'])
    assert len(goods_names) == 16 and len(stock) == 22
    goods = {}
    for city in range(24, 46):
        row = []
        for name in goods_names:
            cell = prices['goods'][name][str(city)]
            row.append({'buy': cell['buy'], 'sell': cell['sell'],
                        'wagon_a': cell['wagon_a'][0], 'cap_a': cell['wagon_a'][1],
                        'wagon_b': cell['wagon_b'][0], 'cap_b': cell['wagon_b'][1]})
        goods[str(city)] = row
    return {
        'source': 'glieu.alis 0xcd1/0xd23/0xd5f/0xdd2 and TABLE 0x75d..0xf0a; see tasks/evidence/city-scripts.md',
        'city_names': [source['city_names'][str(i)] for i in range(46)],
        'goods_names': goods_names,
        'goods': goods,
        'mammoths': {k: _offer(v) for k, v in prices['mammoths'].items()},
        'slaves': {k: _offer(v) for k, v in prices['slaves'].items()},
        'soldiers': {k: _offer(v['enrol']) for k, v in prices['soldiers'].items()},
        'spies': {k: _offer(v['spy']) for k, v in prices['soldiers'].items()},
        'stock_init': stock,
    }


if __name__ == '__main__':
    output = ROOT / 'reference-private/commerce.json'
    output.write_text(json.dumps(build(), indent=1))
    print(output)
