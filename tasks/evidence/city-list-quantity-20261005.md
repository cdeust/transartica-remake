# City quantity layout review, 5 October 2026

Independent review of the pending `city_screen.gd` correction found that the native icon regression still expected the previous single-line name/quantity format. Updated only `test_city_list_icons.gd` to expect the complete name and integer separated by a newline. Its captures now use a dedicated directory, preserving earlier campaign evidence.

Executed `.toolchain/Godot.app/Contents/MacOS/Godot --path game --script res://tests/test_city_list_icons.gd` in a separate native renderer instance. Exit 0; OpenGL 4.1 Metal compatibility renderer; output: `PASS: authored goods16/wagons25 icons, unchanged source rows/text and native list selection`. The test verifies original goods IDs, quantities, icon mapping, keyboard selection and workshop selection. No native-play console input or campaign save operation was used.

Inspected `tasks/validation/city-list-quantity-20261005/goods-after.png` and `wagons-after.png`: complete names and numbers occupy separate lines. Full test output is `native-test.log` in that directory. Earlier earned Turin capture `tasks/validation/continuous-play-20261003/12102.png` shows the complete quantity 61 under LINE INSPECTION CARS.

Current-source `test_city_list_text.gd` and `test_city_trade.gd` also exit 0. Text metrics pass at 1440×900, 1280×800, 960×540 and 640×800. Source and craftsmanship checks for both the production file and the updated test report zero errors and zero warnings. `git diff --check` passes. The separate renderer process exited normally.
