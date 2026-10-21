# Runtime resource inventory, 21 October 2026

Scope: user now explicitly requests that the game resources be versioned and included in built games. This inventory selects the runtime closure only. It does not reclassify historical content under MIT.

## Verified source

`noita-pixel-world/output/standalone-native-graphics-20261021/Transartica.app/Contents/Resources/game/` is the source of the validated closure. Its `resource-inventory.json` contains 120 entries. Every size and SHA256 was checked against the actual file; zero mismatches. The corrected eight paintings and manifest also match `reference-private/graphics-corrections-20261021/world-hd/` byte for byte.

The current `native-game/packaging/runtime-assets.json` has one deliberate path change relative to this older package: the native eight-frame obstacle descriptor is now `assets/travel/terrain/scenes/obstacles-native.json`, with the exact same bytes and SHA256. Keep the shared six-frame `assets/travel/terrain/obstacles.json` from main unchanged.

## Counts and layout

| Selection | Files | Bytes |
| --- | ---: | ---: |
| Complete game resource closure | 120 | 191811138 |
| Authored/selected assets, including paints and score | 85 | 190066207 |
| Decoded historical gameplay/audio inputs | 35 | 1744931 |
| Corrected world-hd selection, included above | 9 | 27990512 |
| New files versus published port branch | 43 | 29729292 |
| Existing world-artwork.png replacement | 1 | 3450824 |
| Existing unchanged resource files | 76 | 158631022 |
| Additional font, already tracked | 1 | 2049096 |

Recommended tracked layout: retain `game/assets/` and `game/data/` for native gameplay inputs. Add only the 35 historical input files listed below and the eight corrected region PNGs; replace the existing overview `world-artwork.png`. All copied resources must be regular files, with no links to another worktree. Current code and the packaging allowlist then resolve these resources with the native data-directory migration.

The new resource bytes total 29,729,292. The overview replacement increases its tracked size from 3,113,939 to 3,450,824 bytes. The largest runtime file is `game/assets/audio/orchestral/danger.wav`, 10,263,316 bytes; no selected file reaches 100,000,000 bytes. No LFS split or archive is needed for this selected closure.

## Attribution and supporting metadata

Retain `game/assets/interface/original-data-manifest.json` (16,624 bytes): all 35 historical closure files match this edition manifest and are marked edition_verified by the package inventory. Preserve its full original paths and hashes. It is already tracked and used by packaging for integrity checks.

Retain `game/assets/audio/orchestral/LICENSE.md` (920 bytes) and the score manifest: this is the separately authored score using the recorded sample-library attribution. Preserve `native-game/assets/fonts/OFL.txt` verbatim (4,396 bytes), its README provenance (582 bytes), and the font. The project MIT license covers new source code, not automatically these historical inputs. Existing package/runtime notices describing all resources as private now need wording reflecting the new publication instruction while retaining content attribution.

The historical audio manifest contains entries outside the eight runtime-selected scripts; the packager traverses only berta, present, scene1, scene3, scene4, son, train and wdecor. Copy the 26 selected sample WAVs plus its unchanged manifest, rather than every referenced sample from unused scripts. The score uses the five authored orchestral WAVs below.

Exclude unrelated reference evidence, reproduction saves, hook backups, generated authoring intermediates, executable bundles, dylib copies and temporary build outputs. They are not needed to compile or run this checkout. Runtime resources will be copied into builds by the existing explicit package closure; third-party libraries remain separately sourced by the packager.

## Exact resource paths and sizes

All paths below are tracked-destination paths. The source is the same relative path inside the package `Resources/`, except `scenes/obstacles-native.json`, copied from the active noita source with SHA703ddd339ea3735809bee7672b78cd846cdbc662d76f129c95256ee673ea35e7. Status is relative to `origin/feat/standalone-cpp-playable` as inspected.

| Destination | Bytes | Git action | SHA256 |
| --- | ---: | --- | --- |
| `game/assets/audio/orchestral/cities.wav` | 8912884 | unchanged | `ca8e1b07531b4458c770cefc8f6afb2236001cd76174c3d9783cc455f151ee00` |
| `game/assets/audio/orchestral/danger.wav` | 10263316 | unchanged | `29050fa672cff940b2d2e23a9def4c7cadec996835db0648a354cf04ade688b9` |
| `game/assets/audio/orchestral/exploration.wav` | 8064044 | unchanged | `96a928dd0e6171076d3910cf4e006bb37bf8a899b9b84b200a4a63361b08906e` |
| `game/assets/audio/orchestral/music.json` | 1892 | unchanged | `07f0bfb659e5f203747f983346aaa38d25a719a489896cec4f871ec6ff0eb57d` |
| `game/assets/audio/orchestral/title.wav` | 7362828 | unchanged | `114299d6acfaf756ad751561cabff56a888d3bf270d4e7e0a696f55f35bcd461` |
| `game/assets/audio/orchestral/worksite.wav` | 6513276 | unchanged | `71d331ef166206e6c5225a80c7cdae0adb3d4cbdbcd68fdcea4c39c81cab7825` |
| `game/assets/boudoir/captain-boudoir.png` | 2375216 | unchanged | `59ce602841c297c87c9b989ba86e00d3c1508b4c1324c2f52e5e7a2256ff738f` |
| `game/assets/boudoir/cutouts/boudoir-book.png` | 181001 | unchanged | `cb021ca36f1847f3c5b2f12373a504156d78e4026d91ea4ebc62522e7ce9a88b` |
| `game/assets/boudoir/cutouts/boudoir-kolotov.png` | 270931 | unchanged | `1dcc4f972239366642d671067d1fd337d9cec93f5d45ebf983f18d1da808282a` |
| `game/assets/boudoir/cutouts/boudoir-revolver.png` | 22817 | unchanged | `7582ab1915386c80f7f5947b1f824c485175297f8a2f56d3a736f36ee7cac4c9` |
| `game/assets/boudoir/cutouts/boudoir-stoup.png` | 54689 | unchanged | `66ebd213b73fb897e21ab4edd7689eb253ec7d6c05b48e7cd1260b134844ab43` |
| `game/assets/boudoir/cutouts/quarters-map.png` | 664517 | unchanged | `87bc6c56e50200438ae0f13b03da00e7ac5d715dcfaad0f00ecd7ee987100b13` |
| `game/assets/boudoir/cutouts/quarters-officer.png` | 522441 | unchanged | `8b4bd21c8b5c515e7fa5df0c2cf15fc0fc398b131afc5fb237b6e2a12e0db9bb` |
| `game/assets/boudoir/cutouts/quarters-operator.png` | 140341 | unchanged | `a2647c01d041e7da5cb4fa24294d281ad046243938ab441c0937dff4ccd1a004` |
| `game/assets/boudoir/cutouts/quarters-stoup.png` | 68229 | unchanged | `1e23e213d467e5fcf2d4c02afb26ee696fcfb27d6350e1f3515a09b9a2d3578b` |
| `game/assets/boudoir/general-quarters.png` | 2718831 | unchanged | `36ed4c9742a5ce98323f022fcec53e498783bd60a0756ed72c355ddde9b9e536` |
| `game/assets/campaign/finale-effects.png` | 1929231 | unchanged | `ce2fbb4d8ae6cfc936f2f75ba5df9e7e82563781749b668200c4c91ca1ab91ed` |
| `game/assets/campaign/mausoleum.png` | 2691177 | unchanged | `59529330038d0d3f248c64b3ad2ccd75e3c8c3e190d6698d6594e93eeaa16add` |
| `game/assets/campaign/mole-ambush.png` | 2324400 | unchanged | `cf4bee4a472dcea3daa54fa93e41c2a53756af0ae02c8dab7b626c74d9916142` |
| `game/assets/campaign/oslo.png` | 2699203 | unchanged | `76c14b13727a0f699e5aaee7b2f0593b8170fe32bf9a57efcb7e33ccc160e54e` |
| `game/assets/campaign/slope.png` | 2596081 | unchanged | `1cd28d5349995b05d91af0e11b8f4b91c63137e55d8b07231d530cd715ff2175` |
| `game/assets/campaign/startup.png` | 1920364 | unchanged | `e4288f1459757e8582890f1b0abcb0f0e0024a6b3973cbf76010a0a4116c65b7` |
| `game/assets/campaign/sun-overcast.png` | 2412393 | unchanged | `bb4fd9d89192f41509bae7a45394e1a817e85ddc65fc002f7415784787a0ad72` |
| `game/assets/campaign/sun-restored.png` | 2522979 | unchanged | `d6b85e806c83aee936d9ca8a94d37a584693eb27fee42f15ce712d1073521a25` |
| `game/assets/campaign/urga.png` | 2528245 | unchanged | `6303b9b17455cc2cfdc6528b20aff48280a6ea437ce09751174373792a3400b4` |
| `game/assets/campaign/whale.png` | 2423285 | unchanged | `3be9d5bf006cb929b3c3d0bc1a2a830ab99d3e5f27bbf93782ff1aa385702ba9` |
| `game/assets/campaign/wolf-ambush.png` | 2461961 | unchanged | `052a7e6458521d240ba993b6c85a5f35d675b06117cdb3cb4248b8bffaddfb36` |
| `game/assets/cities/city-garrison.png` | 2620416 | unchanged | `a369b090d95b483450fbeaa26883837b70b0405dc27627c5f0ce8fe5ecdb2eec` |
| `game/assets/cities/city-industrial-workshop.png` | 3006992 | unchanged | `00110840c629d2c15771d81c59f11924ba81d77d8a3be8c6e18cc08b2f301be6` |
| `game/assets/cities/city-information.png` | 2621269 | unchanged | `3c4b0abda3ed429b577eb949b159e2b307aded9ef3abb23ae80c7a137fd8214e` |
| `game/assets/cities/city-mammoth-fair.png` | 2817402 | unchanged | `4a314c6553bf418ff4e3ccd69020222123e2b28f283507f55cadb8c4111a7fc0` |
| `game/assets/cities/city-slave-market.png` | 2584704 | unchanged | `ff5492ad36a4eae7501a514a6db1714189dd98de98cb7683ad962436e3c4e3e8` |
| `game/assets/cities/city-trading-station.png` | 2982498 | unchanged | `6c83bacc9be65e8f398c1ba329c3f1b56ca244dc3981a24cd9e5407badb2a0ba` |
| `game/assets/cities/goods-icons.json` | 1727 | unchanged | `be08a7a697c83529c8848c6f88ece555e7c20084de31eae2485f218fdf79ed31` |
| `game/assets/cities/goods-icons.png` | 1304943 | unchanged | `65d99811c0f8d5f7bd1271b6b0b75652e68e51d662126f3db737eb50b86a9774` |
| `game/assets/combat/background.png` | 2375553 | unchanged | `1f3accb32d2c7837d092741bbf86e5d16e9db8e1bc217a71a76574cc71ef7a96` |
| `game/assets/combat/mammoth-poses.png` | 988821 | unchanged | `6fe08450d5c33d4b0181f2fdfd4d75836a6d1b0ac660318cb446748a312c521c` |
| `game/assets/combat/train-master.png` | 1708978 | unchanged | `bfad4681eb476ef4f388660e6df97647fa6a4da57e3f2dc08b0260c0075df5c9` |
| `game/assets/combat/trooper-poses.png` | 78044 | unchanged | `49201f88bbbcc91e3b47477ed738f82543ca63711cad8da79ebeffe954810037` |
| `game/assets/combat/trooper-rig.png` | 6029 | unchanged | `ea3224947c86f3ab98aa593b2118f7b825ffc46f76056676e4bca65b0e382c02` |
| `game/assets/combat/wagon-01.png` | 1873208 | unchanged | `daddf434129246da326c6a91650d7d5e02e402acc33078e6c72722d709a07788` |
| `game/assets/combat/wagons-master-04-10.png` | 2477097 | unchanged | `3c2c885aa452106056c4d1e62549b86202784efeac3bc28fbdb4833d1ff58874` |
| `game/assets/combat/wagons-master-10-17.png` | 2494549 | unchanged | `f00fe83347e2c93ab645f2eca4974850b7561bcde59dc572c457cd9f8a600ae7` |
| `game/assets/combat/wagons-master-17-25.png` | 2611970 | unchanged | `4bf752fea5e0ce25a1eaccab451a9bb76a93f786259d395ae1a7162974846210` |
| `game/assets/effects/living-atlas.json` | 3052 | unchanged | `b2c2254f91650eedafaddbedf3babfea2b20799a74acce86847023f00dbc6e25` |
| `game/assets/effects/living-atlas.png` | 2094223 | unchanged | `2bcdee4c261497f1e16050783ac404b9275cf844ed5ee2383ecb7b0cf7f4a4c7` |
| `game/assets/engine-room/background.png` | 2857266 | unchanged | `6b90be7f50f9ab8b0405d36efb8316c896f097c5692ad87d0bc5723e85f27c17` |
| `game/assets/engine-room/engineer-mask.png` | 309382 | unchanged | `00832865e09af5357a5a4a0636b235e069f5c744eb9e703941c8e0243c9838ec` |
| `game/assets/engine-room/fire.png` | 999142 | unchanged | `e9a86fb52feee1437bdf5b18920adbd2abe923b5edd27631c2cd788ca6c52aa7` |
| `game/assets/engine-room/instruments.png` | 3126864 | unchanged | `fde92619a6f07b175e71e368a819ea57d928824c616a1dcf82e3a5fd5d34ba1c` |
| `game/assets/engine-room/interface-mask.png` | 251462 | unchanged | `bc0cad80d0058b24eb6d4e07e044c79708d4eef69d43dfd6a4dc1995260e045b` |
| `game/assets/engine-room/stokers.png` | 1979055 | unchanged | `957613b7aa4a7055b32a92c7e293f080e10bf31e87d7a58e227bb3f18960644c` |
| `game/assets/interface/inventory-frame.png` | 704083 | unchanged | `d2637468a53c14dcd8f048082033767fbc5a6e2637bf771c1faf83037d3fc822` |
| `game/assets/interface/launcher-rocket.png` | 1047920 | unchanged | `3d4796212c59c333fa706df48568959eb954d6126d0c07c7f2b29e3e4acbfb97` |
| `game/assets/interface/launcher.png` | 2699766 | unchanged | `30b1839de569f43bb1e281ef1e1529f50118939de3714c890a14dd9bb81fbace` |
| `game/assets/interface/mort-earth.png` | 1708800 | unchanged | `918aa442adacc6b39dbd04fc33c49cd1a65177cf3cf1ef45e4a454badc42c43e` |
| `game/assets/interface/original-panel-v2.png` | 1769258 | unchanged | `489ca42bc9971abfe99f0985ff4cf14c6fa6dc158586949ac884e7e815037e2c` |
| `game/assets/interface/panel-icons.png` | 2295565 | unchanged | `a85acb24d1c803030ccc4ed91ccc9a3a46e949deff6b7bbc0ae54c275e586fca` |
| `game/assets/interface/panel-launcher.png` | 1589255 | unchanged | `f3414612ffc265c34106ecc381373d873270ac6d4513fb93306ed0be3e0e67a6` |
| `game/assets/interface/reception.png` | 2077211 | unchanged | `32e306a4369edd40c7919c23978d32f83eb4517389a75432e358cfa7dfec8cc6` |
| `game/assets/interface/world-chart-frame.png` | 790960 | unchanged | `c2b99042ed99b3fa4267e7033f3af14c77821fb9995032b45964daf8b05ff130` |
| `game/assets/travel/artwork/world-hd/manifest.json` | 6151 | unchanged | `af395bffada3efba7a4063ffdbab7757edfc7bb88c8ad67a2adf1d7dfdc70186` |
| `game/assets/travel/artwork/world-hd/region-00.png` | 4035649 | new | `d65671c825bb077f614fa667b1b8fdbf06c0ab420082d8a051725c3f09199a66` |
| `game/assets/travel/artwork/world-hd/region-01.png` | 3940553 | new | `64939b9aeb149c2fdaf3bcfa7838600680a92995cd387168906b17b4c0542aa6` |
| `game/assets/travel/artwork/world-hd/region-02.png` | 3293507 | new | `2887ef3f048c01a48207b85503315c4d25e9883357c9b38b6aff709c621bea51` |
| `game/assets/travel/artwork/world-hd/region-03.png` | 3532707 | new | `b8526c782c8c4673d91b776c2c98f20c23c813be84b9bc641bbc64a7023cec0b` |
| `game/assets/travel/artwork/world-hd/region-04.png` | 3098248 | new | `7dc980c8de5ec3a8e50c662992768e42b10a5f9e429704a59ebbae007b87f7e8` |
| `game/assets/travel/artwork/world-hd/region-05.png` | 2975567 | new | `83947cd865bcbd850e3d8750e16424e5ca6845c27489d806e0e7b7ca9beb1269` |
| `game/assets/travel/artwork/world-hd/region-06.png` | 3471366 | new | `01e7b472bb9331f5817aa6bdff33cd88b36e1add3ba6dbcac53971d656e72a57` |
| `game/assets/travel/artwork/world-hd/region-07.png` | 3636764 | new | `f7fc9353cbea73783b969c7c9cacc8f1a51f4babb5fdd50b150c0e504e72974e` |
| `game/assets/travel/locomotive-hero.png` | 1460801 | unchanged | `cc66213a1d594f8e4c15426ef4b36a3e850fd6073c6c358f33aa298de0fc4096` |
| `game/assets/travel/rail-track-kit.png` | 2028560 | unchanged | `6905fe2c3a7c6a4788958bf47e85b6d9f43c8352b3c8edbc5c6d1ad3d660ae26` |
| `game/assets/travel/terrain/landmarks-master.png` | 2001636 | unchanged | `e07056d80d16036368cc288500bad6c18afb4ff0300cad0dd216efbb94aeec85` |
| `game/assets/travel/terrain/scenes/obstacles-native.json` | 3288 | unchanged | `703ddd339ea3735809bee7672b78cd846cdbc662d76f129c95256ee673ea35e7` |
| `game/assets/travel/terrain/scenes/bridges-only-v1.png` | 1497668 | unchanged | `19fc7e79c5da692cca2813fdcd1480051f7f059bf4d26545e08bc047e1c3c4a5` |
| `game/assets/travel/terrain/underground-mouths.json` | 3531 | unchanged | `dc0782286f681f124a955e76c7facf4646dfaec8e0412264493e7ee234039e12` |
| `game/assets/travel/terrain/underground-mouths.png` | 1740857 | unchanged | `3257c10443d3c9dc1832c29d1e373808a00d0079b4202b009aa7d65cebab3427` |
| `game/assets/travel/terrain/world-artwork.png` | 3450824 | replace | `f580e38f06d4e0074cf7166a54d920043bc50ccdb925d6a1e0a793e194f5b40b` |
| `game/assets/travel/vehicles-overhead.json` | 7972 | unchanged | `6b0bd238d096f721b5b9f6c09d55204454e14f1200293f147fe37325dd6ada73` |
| `game/assets/travel/vehicles-overhead.png` | 3758811 | unchanged | `d7629e2e79b80942167bdc2c11af21167a3cc27309f5d395b13df03c4c673114` |
| `game/assets/weapons/gatling.png` | 1354786 | unchanged | `b976fe061e763f50365a8e8fb226e4fbecc9b8ce3c0a8e4022762c5d5fd1ee29` |
| `game/assets/world-events/mammoth-hunt.png` | 2986951 | unchanged | `be703ea3af55623d848c8efec154b6b0337f007b57fed150a6791cfbb0525af6` |
| `game/assets/world-events/mine.png` | 3029449 | unchanged | `2013e08c36d7b3afb8f74ca4aab4fba65a3986f0a9478eafab02a0158f18bcc8` |
| `game/assets/world-events/nomads.png` | 2648711 | unchanged | `b60e8f7174dbf3c15fde6988af7140099d0f3e5699447aebe2e122b3066d2a6a` |
| `game/assets/world-events/track-works.png` | 2597814 | unchanged | `23d6e6c4ba48d848f7e1441cd336a3ba64d8a5dfef47019b62fb12fff736b076` |
| `game/data/CARTE.FIC` | 11680 | new | `8e1067619b254d57717348fefedc1b5013eb1d7ba23200a815e36f9b856d811a` |
| `game/data/audio/berta-0.wav` | 540 | new | `83a12156b9d37f26c96d33b4eeaa9664374fc07ec46dc61c0361b90c344bfd24` |
| `game/data/audio/berta-1.wav` | 20016 | new | `c0898115f836b8ac25892bf579962cd03fcffac988522c3c35eb334ff8b96ce8` |
| `game/data/audio/manifest.json` | 127863 | new | `00244d50933fe6aba5e9ec0e37659e1d7600c322ebbfe637f76df3878e2dd625` |
| `game/data/audio/present-0.wav` | 33058 | new | `a54568ae2723bcfd4e30b9bfefef574cf1525eb0588520da06af8ce6608bc2cf` |
| `game/data/audio/scene1-0.wav` | 7360 | new | `f4be75fd524a70653c63b5f029aa912aa1d19aae1b2b74fc740670d0569c0cf7` |
| `game/data/audio/scene1-1.wav` | 16556 | new | `6e5acbd9e0b4cd0b2c3e02c0d1f71678b2085e71a7209f98b11daadf8726f495` |
| `game/data/audio/scene1-2.wav` | 10958 | new | `7306d4d33fe385a138ba4825b617a71b19e0938980d47420ec59d0817160be3a` |
| `game/data/audio/scene3-0.wav` | 34018 | new | `05c3b5ddc8a853cf39285aed5dcf99661a5f5ed0a9a66698ea9a8b909ec88de8` |
| `game/data/audio/scene3-1.wav` | 17194 | new | `571d1a7cbfce4461ffea365f12846d6ff4611e4e7523ea20ff50c2da0d26fe04` |
| `game/data/audio/scene3-2.wav` | 14588 | new | `b9512a71d5616eba61aac6fd64b90996ec8499d4ca1f5d98f715fde80b291a46` |
| `game/data/audio/scene4-0.wav` | 60410 | new | `22714ade5ece11cc33b51fba6207944a228f1ebc2f339c7e2a02f528e78f914e` |
| `game/data/audio/scene4-1.wav` | 20878 | new | `5a810adf7ffab41c9e239e341427b6e8d3ccb02de950bd9ea85670b6acfb83a9` |
| `game/data/audio/scene4-2.wav` | 20878 | new | `5a810adf7ffab41c9e239e341427b6e8d3ccb02de950bd9ea85670b6acfb83a9` |
| `game/data/audio/son-0.wav` | 5418 | new | `de413193aad1ece0c7f326ecf92361e96ed47b3b125905a00c39dbba310c25a1` |
| `game/data/audio/son-1.wav` | 8296 | new | `8512b474a484f17aa7c88e948d4e00fd23f5a4cd3aba8a2fc772c2f9660659fb` |
| `game/data/audio/son-2.wav` | 5018 | new | `e0542d5558ae7ae15e6002787ade49d56c840e17c2c5b31fdfea1e2abe996910` |
| `game/data/audio/son-3.wav` | 2400 | new | `0053746ddfb630ad1ff0255bd89c2451a598624ef829ad09d066e8e5bf39e79d` |
| `game/data/audio/son-4.wav` | 5938 | new | `5793419619698586f0df4a85d2919dd8837b703a3dc160568399ab51932f0bda` |
| `game/data/audio/son-5.wav` | 4950 | new | `ddca4368449228040aefe669bb52dbaa76a765e918a40a3463ecd4f4aa4de985` |
| `game/data/audio/son-6.wav` | 5590 | new | `54482a76ab28d6d9b6e64953f0bdbb72a4f025a5598f7f123641996c0c823973` |
| `game/data/audio/son-7.wav` | 7024 | new | `5ef46225860b5d4d2d923e733992d88e068065a2c497ee556eeaf27111ecde77` |
| `game/data/audio/train-0.wav` | 2968 | new | `51bb96f31a8ea7656106dc0e1d5ae91222a92c8b5313aa0c22b29809881eb037` |
| `game/data/audio/wdecor-0.wav` | 6334 | new | `3d900a29c3f971d6667f8a8e91ae090b11862458c803d49eaf483c3d3f24edf4` |
| `game/data/audio/wdecor-1.wav` | 10008 | new | `9cd77eb74c00938a872a997e08cd05f9b139e10610b33456c52c1c82a7d84e35` |
| `game/data/audio/wdecor-2.wav` | 7360 | new | `17f62969799da910e5d5854f35534839d460f23861871ef396c8fb38d86086e0` |
| `game/data/audio/wdecor-3.wav` | 4860 | new | `ae4249d1594f2840815fbaf196431aba7c9260da3925fc58ba30275bd675e2c3` |
| `game/data/audio/wdecor-4.wav` | 11680 | new | `00ad12098548cd4a3ad5386df3315163ead437bdec75ac5b98ccdc6e363a7b85` |
| `game/data/campaign.json` | 19838 | new | `f97758998e880ef974613445ada6a1b59c6ea2b145cf5679815e5c5ccf7490aa` |
| `game/data/commerce.json` | 53056 | new | `7af388740db5f4bb3d8740f89f91caded4d51f421d487320c413b79169e1eb48` |
| `game/data/finale.wav` | 1141352 | new | `78fa781477d5c55d7b94beecb466e14688ed76d2a4eb934192c301ea5c119399` |
| `game/data/overview-geometry.json` | 35635 | new | `5b4ce6aacb197a66d8d7f97fe638a37d88c7798e69df3585b6a5e8286e388f13` |
| `game/data/startup.json` | 415 | new | `32c83a103ea86a3f1ce8123ae08bcfdde12038cc92ace1be230b953359847153` |
| `game/data/textek.json` | 6055 | new | `645caffa35d5ae003cf61f16aadef6696fefdf4c0e774a8352dc70e9b0e797a3` |
| `game/data/villes-decoded.data` | 4739 | new | `874a4717840fffe2ae6573b268d765b2946d7ac6278fe198017c07b6bca7768d` |
