# FORGE food guide price references

Checked 28 October 2026. These are budgeting references, not live inventory or guaranteed national prices. Prices exclude delivery, cooking fuel, spices, sauces and preparation labour. Nutrition/serving yields must be calculated independently.

## Official survey range

[PBS SPI Annexure, week ended22 October2026](https://www.pbs.gov.pk/wp-content/uploads/2020/07/Annex_22.10.2026.xlsx) was fetched and read in memory using openpyxl. In Appendix-A, **lower header row119 M119 is labelled National Average**, and row120 labels M/N/O as MIN/AVG/MAX. Data rows123 onward contain the national summary in M/O (zero-based indices12/14). The top header row3 uses M/O for Sialkot; those top-block cells were not used. We use MIN and MAX. This is the latest annexure linked by the [PBS price statistics page](https://www.pbs.gov.pk/price-statistics/) on the review date.

| Item | PKR low–high | Unit / interpretation |
| --- | ---: | --- |
| eggs | 240–280 | dozen; PBS surveyed range |
| milk | 170–280 | litre; PBS surveyed range |
| yogurt | 190–400 | kg; PBS surveyed range |
| masoor | 230–330 | kg; PBS surveyed range |
| atta | 110–177 | kg; PBS surveyed range |
| rice | 110–200 | kg; PBS surveyed range |
| banana | 80–260 | dozen; PBS surveyed range |
| potato | 30–90 | kg; PBS surveyed range |
| oil | 618–623 | litre; PBS surveyed range |
| chana | 315–315 | kg; one retail quote, low = high |
| chicken | 1173–1173 | kg; one retail quote, low = high |
| oats | 845–845 | kg; one retail quote, low = high |
| peanuts | 1350–1350 | kg; one retail quote, low = high |
| dates | 670–670 | kg; one retail quote, low = high |

## Retail evidence

- [Al-Fatah boneless chicken breast, Faisalabad, 1 kg](https://alfatah.pk/products/chicken-breast-boneless-lahore-only-1-kg-333) — Direct Shopify product .js endpoint returned 1 KG price 117300 paisa (PKR 1,173); 500 GM 58650 paisa. A single branch-specific quote; no live-broiler conversion.
- [Al-Fatah Nature’s Own white oats pouch, 1,000 g](https://alfatah.pk/products/natures-own-cereal-white-oats-pouch-1000-gm) — Direct product .js returned price 84500 paisa (PKR 845) for 1,000 g. Single product quote; other brands and smaller packs differ.
- [Al-Fatah white chana bareek, 1 kg](https://alfatah.pk/products/white-chana-bareek-zb-1-kg) — Direct product .js returned 31500 paisa (PKR 315) for whole white chana 1 kg. This replaces the older indexed PKR285 quote and is distinct from split daal chana.
- [Al-Fatah AUK Premium Zehdi dates, 500 g](https://alfatah.pk/products/auk-premium-zehdi-dates-500gm) — Direct product .js returned 33500 paisa (PKR335) per 500 g; normalized to PKR670/kg. Typical edible dates; premium Ajwa/Mabroom prices are not substituted.
- [Zaroori Saman shelled peanuts, 1 kg](https://www.zaroorisaman.com/shop/dryfruit/momphali-peanut-without-shell-1-kg/) — Fetched primary product page displays sale PKR1,350 and crossed-out PKR1,400, additional information weight 1 kg. Uses current displayed sale quote only; no shell-yield assumption. Unrelated seller health claims were not used.

## Interpretation limits

- PBS Pulse Gram is not confidently identified as whole chickpeas, so it is deliberately **not** the chana reference. A separately verified whole white chana product is used.
- Direct Al-Fatah product JSON was fetched using the product page URL plus `.js`; integer prices are paisa, divided by100. Search-index prices were sometimes older (chana285 vs direct315; chicken1180 vs direct1173); the direct fetched variant is recorded.
- Never use the PBS live-broiler weight price as boneless chicken meat cost.
- Dahi prices are for loose plain yogurt; Greek yogurt has different cost and nutrition.
- The date quote is for Zehdi dates, not fresh immature dates or expensive premium cultivars.
- Peanut quote is shelled weight. Another primary seller, Anaajpur, showed salted shelled peanuts at PKR300/200g (PKR1500/kg), but that salted preparation is not used for the plain/raw peanut price.
- Serving estimates for cooked lentils, rice, chickpeas and chicken require explicitly stated dry/raw input quantities. No retailer or PBS source supplies a universal cooking-yield conversion.
- The only modeled prices should be per-serving conversions in the app; no invented market-range padding was added here.

## Independent 17-city re-audit (28 October2026)

All nine included PBS ranges were recomputed from the city cells, independently of the national summary. Positive values only: zero entries denote unavailable quotations, not free food. The first block has7 cities, second7 and third3. For item serial `i`, the data row numbers are `i+6`, `i+64`, `i+122`. Within each row, zero-based MIN column indices are `3+3*c`; MAX indices are `5+3*c`. Lower header rows119/120 explicitly identify the national MIN/MAX at M/O.

| Item | Source rows, 1-based | Min/max across all17 city quotations, original unit | Lower summary M/O |
| --- | --- | ---: | ---: |
| Wheat flour bag | 7,65,123 | 2200–3540 per20kg | 2200–3540 |
| IRRI rice | 9,67,125 | 110–200 perkg | 110–200 |
| Fresh milk | 14,72,130 | 170–280 perlitre | 170–280 |
| Dahi | 15,73,131 | 190–400 perkg | 190–400 |
| Farm eggs | 17,75,133 | 240–280 perdozen | 240–280 |
| Cooking oil tin | 19,77,135 | 3090–3115 per5litres | 3090–3115 |
| Local bananas | 22,80,138 | 80–260 perdozen | 80–260 |
| Washed masoor | 23,81,139 | 230–330 perkg | 230–330 |
| Potatoes | 27,85,143 | 30–90 perkg | 30–90 |

Reproducible Python extraction (read the XLSX bytes into `openpyxl.load_workbook(..., data_only=True)`):

```python
sheet = workbook['Appendix-A']
for item in [1,3,8,9,11,13,16,17,21]:
    rows = [[cell.value for cell in sheet[row]]
            for row in [item+6,item+64,item+122]]
    minima, maxima = [], []
    for row, city_count in zip(rows,[7,7,3]):
        assert row[0] == item
        minima += [row[3+3*c] for c in range(city_count)
                   if isinstance(row[3+3*c],(int,float)) and row[3+3*c]>0]
        maxima += [row[5+3*c] for c in range(city_count)
                   if isinstance(row[5+3*c],(int,float)) and row[5+3*c]>0]
    assert (min(minima),max(maxima)) == (rows[2][12],rows[2][14])
```

All assertions passed. No price figures required correction; only coordinate documentation was made explicit.
