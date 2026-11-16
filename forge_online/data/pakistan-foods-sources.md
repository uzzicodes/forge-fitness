# Pakistani food starting references

This is a bounded, editable collection for FORGE's automatic meal review. It is **not** a list of every Pakistani food, a laboratory analysis of national dishes, or manufacturer/restaurant nutrition. A text description cannot establish the oil, recipe, size or brand of an unknown meal.

## Numerical source

The nutrient inputs are the USDA FoodData Central SR Legacy records already imported by FORGE. Each `reference` entry includes its actual FDC ID and source name. Each `recipe` entry includes every modeled ingredient's FDC ID and grams, the assumed final cooked yield in grams, and a source label that says it is a FORGE recipe model.

- [USDA FoodData Central data documentation](https://fdc.nal.usda.gov/data-documentation/) describes SR Legacy as historical nutrient data derived from analysis, calculations and published literature; its final release was April 2018.
- [USDA dataset downloads](https://fdc.nal.usda.gov/download-datasets/) provides the SR Legacy source.
- The [Food Composition Table for Pakistan, revised 2001, hosted by FAO](https://www.fao.org/fileadmin/templates/food_composition/documents/regional/Book_Food_Composition_Table_for_Pakistan_.pdf) was located as a possible future validation source. It is a scanned table. **No unverified numerical value from that document is used here.** The modeled recipes must not be labelled as Pakistan-table measurements.

## Calculation and schema

`foods[].id` is a stable `pk-*` string, deliberately distinct from an official USDA FDC ID. `calories`, `protein`, `carbs` and `fat` are per 100 g of the modeled edible food; `per100g` repeats these fields for explicit integration. Protein/carbohydrate/fat units are grams and energy is kcal. Only these four fields are calculated for recipes; absence of sodium, vitamins or other nutrients must not be displayed as zero.

For each macro, whole-recipe value = sum(ingredient grams × ingredient value per 100 g ÷ 100). Per-100-g recipe value = whole-recipe value × 100 ÷ `yieldGrams`. Values are rounded to one decimal only after summing. Estimated cooking-water loss is represented by the declared final yield. No separate measured nutrient-retention factor is claimed.

`defaultPortion` is `{unit, grams, label}`. Portions use singular units such as `piece`, `bowl`, `plate`, `cup`, `glass` or `serving`. Every assumed cooked size is stated in the label. Household bowls and plates have no universal weight. `densityGramsPerMl`, where supplied for drinks, is an approximate conversion for that modeled drink, not a measurement of every recipe. The 93 original entries were expanded to 98 to distinguish chicken/beef variants and sweetened black tea.

`kind: reference` means a USDA generic food, not a branded Pakistani packet. `kind: recipe` means an explicitly authored, editable starting recipe assembled from those ingredient values. `ingredients`, `yieldGrams`, `assumptions`, `source` and `uncertainty` must remain associated with the estimate. Display the assumptions before confirmation. For actual restaurant/packaged data, prefer the restaurant's published nutrition or the exact packet label.

## Coverage and examples

The collection includes homemade roti, ghee roti, paratha and filled parathas, naan, puri, omelette/bhurji, rice dishes, chicken/mutton/beef preparations, pulse/vegetable curries, samosas/pakoras/chaats/rolls, desserts, chai/doodh patti/lassi/shakes, and generic crisps/biscuits/chewing gum.

- Homemade plain roti assumes 30 g dry atta, water and no added fat, yielding a 40 g cooked roti: about 102 kcal. It deliberately does not use a commercial/oily chapati as a plain home roti.
- Sweet chai assumes 140 g brewed tea + 60 g whole cow milk + 8 g sugar: approximately 69 kcal for the modeled 208 g cup. Unsweetened chai excludes sugar and is about 38 kcal for the modeled 200 g cup. Longer aliases such as “chai without sugar” must take precedence over the generic “chai” alias.
- Plain paratha includes 10 g cooking oil in a 75 g modeled paratha. A richer restaurant paratha can differ substantially.
- A samosa's modeled absorbed oil and assumed piece size are explicit. Mini samosas and large bakery pieces must not silently inherit the same piece weight.
- Generic sugar-containing chewing gum uses USDA 168771; sugarless gum uses 169882. Their protein can be zero while their energy is nonzero. “Bubbles” alone is ambiguous and must not be assigned either record without clarification.

## Ambiguity and implementation cautions

`clarifications[]` supplies short follow-ups for ambiguous names: bubbles/bubble, Napoleon chicken, unqualified lassi, generic biscuits/packet chips, shami/chapli meat choice, haleem, black tea and lobia. Long, specific aliases must outrank short ones. Do not discard an unknown modifier and fall back to a known substring: “Napoleon chicken” is not plain chicken, and an unsupported chicken pakora must not become vegetable pakora merely because “pakora” is known.

Several recipe inputs use declared proxies: cooked lentils for a shami pulse base, cooked pasta for vermicelli, cooked whole pulses for split/dehulled daals, and generic cooked beef for unknown meat cuts. These entries set `requiresRecipeConfirmation` and retain the caveat. Nihari is particularly variable because marrow, tendon and added fat are not represented by ordinary cooked meat. A user can accept and edit that starting recipe; the app must not present it as an exact identified meal.

`requiresLabelForPackaged` and `requiresPortionConfirmation` flag generic packet-food proxies. Do not identify them as Sooper, Marie, Tuc, Lays, Rooh Afza or another manufacturer product. The rose-sherbet model is generic sugar-and-water nutrition, not a Rooh Afza label. The file contains no invented brand nutrition.

## Local validation

All ingredient IDs resolve to the existing USDA catalogue. All macros and portion weights are finite and nonnegative; IDs are unique; recipe yields do not exceed ingredient mass without declared water; per-100-g macros reproduce the ingredient calculation within rounding tolerance. No production records, schema or personal data were modified to create this file.
