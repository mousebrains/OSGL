%
% Extract down, up, and surface intervals using the output of osgl_glider_state
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function [tDive, tClimb, tSurface, tBottom, tTop] = osgl_cast_intervals(t, gliderstate)
arguments (Input)
    t (:,1) datetime {mustBeNonempty}
    gliderstate (:,1) uint8 {mustBeNonempty}
end % arguments Input
arguments (Output)
    tDive (:,2) datetime
    tClimb (:,2) datetime
    tSurface (:,2) datetime
    tBottom (:,2) datetime
    tTop (:,2) datetime
end % arguments Output

tDive = mkIntervals(t, bitand(gliderstate, 8) ~= 0);
tClimb = mkIntervals(t, bitand(gliderstate, 32) ~= 0);
tSurface = mkIntervals(t, bitand(gliderstate, 1) ~= 0);
tBottom = mkIntervals(t, bitand(gliderstate, 16) ~= 0);
tTop = mkIntervals(t, bitand(gliderstate, 4) ~= 0);
end % osgl_cast_intervals

function a = mkIntervals(t, q)
arguments (Input)
    t (:,1) datetime
    q (:,1) logical
end % arguments Input
arguments (Output)
    a (:,2) datetime
end

delta = diff(q); % +1 is one before an interval starts, -1 is when the interval stops
i0 = find(delta == 1) + 1;
i1 = delta == -1;

if isempty(i0)
    a = NaT(0,2);
    return
end % if isempty

if numel(i0) ~= sum(i1) % Runs off the end
    i1(end) = true;
end % if numel

a = [t(i0 + 1), t(i1)];
end