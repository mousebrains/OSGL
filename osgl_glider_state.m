% Rewrite of my older dive/climb finding code to take advantage of recent
% firmware updates.
%
% This has been tested with TWR Slocum firmware versions:
%  10.8
%
% tbl must contain at least four columns:
%  m_present_time
%  cc_behavior_state
%
% Returns a bit mask with 7 possible bits set:
%  0 -> Undefined state
%  1 -> At surface
%  2 -> Ending surface behavior
%  4 -> Inflecting downwards
%  8 -> Stable dive
% 16 -> Inflecting upwards
% 32 -> Stable climb
% 64 -> Climbing to the surface
%
% cc_behaviour_state from masterdata:
%   # -1 ; None
%   #  0 ; actively inflecting or in the post surface interval
%   #  1 ; dive activated this cycle
%   #  2 ; climb activated this cycle
%   #  3 ; hover activated this cycle
%   #  4 ; not transitioning, active dive/climb/hover
%   #  5 ; surface activate
%   #  6 ; surface activated
%   # 99 ; ignore
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function gliderState = osgl_glider_state(tbl)
arguments (Input)
    tbl table
end % arguments Input
arguments (Output)
    gliderState (:,1) uint8
end % arguments Output

b = tbl(~isnan(tbl.m_present_time) & ismember(tbl.cc_behavior_state, [1, 2, 5, 6]), ...
    ["m_present_time", "cc_behavior_state"]); % A new behavior has been activated
[~, ix] = unique(b.m_present_time);
b = b(ix,:);

tbl.active = interp1(b.m_present_time, single(b.cc_behavior_state), tbl.m_present_time, "previous", "extrap");
tbl.active(isnan(tbl.active)) = 0; % Unknown active state

qSurf      = ismember(tbl.active, [5,6]) & tbl.cc_behavior_state == 5; % At the surface
qUnsurface = tbl.active == 5 & ismember(tbl.cc_behavior_state, [-127, 0]); % Stopping surface
qDown      = tbl.active == 1 & ismember(tbl.cc_behavior_state, [0, 1]); % Inflecting downwards
qDive      = ismember(tbl.active, [1,5]) & tbl.cc_behavior_state == 4; % Stable dive
qUp        = tbl.active == 2 & ismember(tbl.cc_behavior_state, [0, 2]); % Inflecting upwards
qClimb     = tbl.active == 2 & tbl.cc_behavior_state == 4; % Stable climb
qSurfacing = tbl.active == 6 & ismember(tbl.cc_behavior_state, [0, 4, 6]); % Climbing to the surface

gliderState = ...
    qSurf .* 1 + ...
    qUnsurface .* 2 + ...
    qDown .* 4 + ...
    qDive .* 8 + ...
    qUp .* 16 + ...
    qClimb .* 32 + ...
    qSurfacing .* 64;

gliderState = uint8(gliderState);
% end % osgl_glider_state