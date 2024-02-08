%
% Extract dive/climb start/end times as a triplet, start of dive, bottom of dive and climb, and end
% of climb.
%
% This is a rewrite of code I have for 2012, taking advantage of both Matlab improvements and
% algorithm improvements.
%
% Feb-2024, Pat Welch, pat@mousebrains.com

function times = osgl_dive_climb_times(time, depth, opts)
arguments (Input)
    time (:,1) datetime % Time of each depth sample
    depth (:,1) double  % Each depth/pressure sample
end % arguments Input
arguments (Input, Repeating)
    opts
end % arguments Input Repeating
arguments (Output)
    times (:,3) table % start of dive, end of dive/start of climb, and end of climb times
end % arguments Output

if numel(time) ~= numel(depth)
    error("The length of time and depth must be equal %d != %d", numel(time), numel(depth));
end % if

pars = get_params(opts);

[~, ix] = unique(time); % Unique and sorted times
tbl = table();
tbl.time = time(ix);
tbl.depth = depth(ix);
tbl = tbl(~isnan(tbl.depth),:); % All valid depths

% Find the bottom turns
[~, iPeak] = findpeaks(tbl.depth, ...
    MinPeakHeight=pars.minBottomDepth, ...
    MinPeakProminence=pars.minPeakProminence ...
    );

if pars.plot
    plot(tbl.time, tbl.depth, "-", tbl.time(iPeak), tbl.depth(iPeak), "o");
    grid on;
    axis ij;
    axis tight;
    xlabel("Time (UTC)");
    ylabel("Depth (m)");
    title(sprintf("%d peaks found", numel(iPeak)));
end % if pars.plot

tbl.qBottom = false(size(tbl.time));
tbl.qBottom(iPeak) = true; % Location of peaks are now tagged
tbl.grp = findgroups(cumsum(tbl.qBottom)); % Intervals between bottom turns

aSurf = rowfun(@findSurface, tbl, ...
    "InputVariables", ["time", "depth"], ...
    "GroupingVariables", "grp", ...
    "OutputVariableNames", ["time", "minDepth", "maxDepth"]);
aSurf = aSurf((aSurf.maxDepth - aSurf.minDepth) > pars.minDepthRange,:); % Drop short turns
aSurf.ix = interp1(tbl.time, 1:size(tbl,1), aSurf.time, "nearest"); % Indices in tbl of top of turns

tbl.qTop = false(size(tbl.time)); % When we're at the top of a turn
tbl.qTop(aSurf.ix) = true;
tbl.grp = findgroups(cumsum(tbl.qTop)); % dive+climb intervals

aDive = rowfun(@findBottom, tbl, ...
    "InputVariables", ["time", "depth"], ...
    "GroupingVariables", "grp", ...
    "OutputVariableNames", ["tLHS", "tBot", "tRHS", "lhsDepth", "botDepth", "rhsDepth"]);

aDive = aDive( ...
    (aDive.botDepth - aDive.lhsDepth) > pars.minDepthRange & ...
    (aDive.botDepth - aDive.rhsDepth) > pars.minDepthRange, :);

times = aDive(:, ["tLHS", "tBot", "tRHS"]);
times.tLHS(2:end) = times.tRHS(1:end-1); % Make sure end of a climb is the start of the next dive
end % osgl_dive_climb_times

function pars = get_params(opts)
arguments (Input)
    opts cell
end % arguments Input
arguments (Output)
    pars struct % start of dive, end of dive/start of climb, and end of climb times
end % arguments Output

p = inputParser();
% Diagnostic plot
addParameter(p, "plot", false, @islogical); % Should a diagnostic plot be generated?
% findpeaks parameters
addParameter(p, "minBottomDepth", 10, @isreal);   % Bottom turn is >= than this value
addParameter(p, "minPeakWidth", 60, @(x) x >= 0); % minimum peak width in CTD bins
addParameter(p, "minPeakProminence", 1, @(x) x >= 0); % How much does a peak standout
addParameter(p, "minDepthRange", 10, @isreal); % dive top to bottom is >= this value

parse(p, opts{:});
pars = p.Results;
end % get_params

function [t0, minDepth, maxDepth] = findSurface(time, depth)
arguments (Input)
    time  (:,1) datetime % Time of each observation
    depth (:,1) double   % Water depth at each observation
end % arguments Input
arguments (Output)
    t0 datetime % time of minDepth
    minDepth double % Minimum depth
    maxDepth double % Maximum depth
end % arguments Output

[minDepth, index] = min(depth, [], "omitmissing");
maxDepth = max(depth, [], "omitmissing");
t0 = time(index);
end % findSurface

function [timeLHS, timeBot, timeRHS, depthLHS, depthBot, depthRHS] = findBottom(time, depth)
arguments (Input)
    time  (:,1) datetime % Time of each observation
    depth (:,1) double   % Water depth at each observation
end % arguments Input
arguments (Output)
    timeLHS datetime   % time at start of dive
    timeBot datetime   % time at end of dive/start of climb
    timeRHS datetime   % time at end of climb
    depthLHS double % Depth at start of dive
    depthBot double % Depth at bottom
    depthRHS double % Depth at end of climb
end % arguments Output

timeLHS = time(1);
timeRHS = time(end);

depthLHS = depth(1);
depthRHS = depth(end);

[depthBot, index] = max(depth, [], "omitmissing");
timeBot = time(index);
end % findBottom