// SPDX-License-Identifier: MIT
#include "session_ui.h"
namespace transartica {
void SessionUI::draw_launcher_map(Canvas&,const Session& state,Cell camera,Point glide) {view_.launcher_map(state,camera,glide);}
void SessionUI::draw_launcher_target(Canvas&,const Session&,const world::EnemyTrain& train,Cell camera,Point glide) {view_.launcher_target(train.cell(),train.heading,camera,glide);}
}
