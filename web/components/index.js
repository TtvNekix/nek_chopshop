import { ViewElement } from './view-element.js';
import { definePrimitives } from './primitives.js';
import { JobBoard } from './job-board.js';
import { JobTracker } from './job-tracker.js';
import { PartsBuyer } from './parts-buyer.js';
import { LooseNote } from './loose-note.js';
import { PartnerInvite } from './partner-invite.js';

/** Tag name for every view id. Adding a view = new class + one line here + VIEWS in state.js. */
export const VIEW_TAGS = Object.freeze({
  'job-board': ['chop-job-board', JobBoard],
  'job-tracker': ['chop-job-tracker', JobTracker],
  'parts-buyer': ['chop-parts-buyer', PartsBuyer],
  note: ['chop-note', LooseNote],
  'partner-invite': ['chop-partner-invite', PartnerInvite],
});

/** Injects dependencies, then defines every custom element. Call once at boot. */
export function registerComponents(deps) {
  ViewElement.provide(deps);
  definePrimitives();
  for (const [tag, ctor] of Object.values(VIEW_TAGS)) {
    if (!customElements.get(tag)) customElements.define(tag, ctor);
  }
}
