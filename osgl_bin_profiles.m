%
% Bin data by profile and depth
%
% This is a rework/modernization of existing code I have.
%
% Feb-2024, Pat Welch, pat@mousebrains.com

function [pInfo, tbl] = osgl_bin_profiles(tbl, times, depthBin, fields)
arguments (Input)
    tbl table % EBD or DBD table of data to be binned
    times (:,3) % dive/climb start of dive (tLHS), bottom (tBot), and end of climb (tRHS)
    depthBin double {mustBePositive} % depth bin width
    fields string = missing % Fields to be binned
end % arguments Input
arguments (Output)
    pInfo table % Profile information
    tbl table   % binned information
end % arguments Output

tbl = tbl(~isnan(tbl.depth),:);

ix = interp1(tbl.time, 1:size(tbl,1), table2array(times), "nearest");

tbl.qTurn = false(size(tbl,1),1); % When did the glider turn
tbl.qTurn(ix(:)) = true; % Glider turns
tbl = tbl(ix(1,1):ix(end,end),:); % Prune to just the data while diving/climbing
tbl.bin = round(tbl.depth / depthBin) * depthBin;
tbl.qTurn(end) = false; % No transition to another dive at end
tbl.grp = findgroups(cumsum(tbl.qTurn)); % Odd are dives, even are climbs

stime = tic();
pInfo = rowfun(@myInfo, ...
    tbl, ...
    InputVariables = ["time", "depth"], ...
    GroupingVariables = "grp", ...
    OutputVariableNames = ["time", "tLHS", "tRHS", "depthMin", "depthMax", "qDive"]);

pInfo = renamevars(pInfo, ["grp", "GroupCount"], ["profile", "n"]);
fprintf("Took %.2f seconds to generate pInfo, %d\n", toc(stime), size(pInfo,1));

if ismissing(fields)
    fields = sort(string(tbl.Properties.VariableNames));
end % if ismissing

vNames = setdiff(fields, ["time", "depth", "grp", "qTurn"]);

stime = tic();

profiles = cell(tbl.grp(end),1);
a = parallel.pool.Constant(tbl);

parfor index = 1:numel(profiles)
    profiles{index} = myBinData(a.Value(a.Value.grp == index, vNames));
end

fprintf("Took %.2f seconds to generate %d profiles\n", toc(stime), numel(profiles));

stime = tic();
bins = cell(size(profiles));
for index = 1:numel(bins)
    profile = profiles{index};
    bins{index} = profile.depth;
end

bins = unique(vertcat(bins{:}));

nProfiles = numel(profiles);
nBins = numel(bins);

indices = cell(size(profiles)); % index mapping for each profile's data
for index = 1:numel(indices)
    indices{index} = ismember(bins, profiles{index}.depth);
end % for index

tbl = table();
tbl.depth = bins;

names = setdiff(sort(string(profiles{1}.Properties.VariableNames)), "depth");
indices = parallel.pool.Constant(indices);
profiles = parallel.pool.Constant(profiles);

for name = names
    val = cell(nProfiles, 1);
    parfor index = 1:nProfiles
        a = nan(nBins, 1);
        a(indices.Value{index}) = profiles.Value{index}.(name);
        val{index} = a;
    end
    tbl.(name) = horzcat(val{:});
end % for name

fprintf("Took %.2f seconds to glue together, %dx%d\n", toc(stime), nBins, nProfiles);
end % osgl_bin_profiles

function [time, tLHS, tRHS, depthMin, depthMax, qDive] = myInfo(time, depth)
arguments (Input)
    time  (:,1) datetime % Time of each observation
    depth (:,1) double   % Depth of each observation
end % arguments Input
arguments (Output)
    time datetime   % Median time
    tLHS datetime   % Start time
    tRHS datetime   % End time
    depthMin double % Minimum depth in depth
    depthMax double % Maximum depth in depth
    qDive logical   % Is this a dive or climb yo
end % arguments Output

tLHS = time(1);
tRHS = time(end);
time = median(time, "omitmissing");
depthMin = min(depth, [], "omitmissing");
depthMax = max(depth, [], "omitmissing");
qDive = depth(1) < depth(end);
end % myInfo

function profile = myBinData(data)
arguments (Input)
    data table
end % arguments Input
arguments (Output)
    profile table
end % arguments Output

data.grp = findgroups(data.bin);

profile = rowfun(@(x) x(1), ...
    data, ...
    InputVariables = "bin", ...
    GroupingVariables = "grp", ...
    OutputVariableNames = "depth");

profile = removevars(profile, "grp");
profile = renamevars(profile, "GroupCount", "count");

bNames = setdiff(string(data.Properties.VariableNames), "bin");

b0 = rowfun(@myMedian, ...
    data, ...
    InputVariables = bNames, ...
    SeparateInputs = false, ...
    GroupingVariables = "grp", ...
    OutputFormat = "cell");

b0 = array2table(vertcat(b0{:}), VariableNames=bNames); % Glue rows together

b1 = rowfun(@myStd, ...
    data, ...
    InputVariables = bNames, ...
    SeparateInputs = false, ...
    GroupingVariables = "grp", ...
    OutputFormat = "cell");

b1 = array2table(vertcat(b1{:}), VariableNames=append(bNames, "_std")); % Glue rows together

profile = horzcat(profile, b0, b1);
end

function mu = myMedian(data)
arguments (Input)
    data (:,:) double
end % arguments (Input)
arguments (Output)
    mu (1,:) double
end % arguments Output

if size(data,1) == 1 % Only one row, so return it
    mu = data;
    return;
end % if

mu = median(data, "omitmissing");
end % myStd

function sigma = myStd(data)
arguments (Input)
    data (:,:) double
end % arguments (Input)
arguments (Output)
    sigma (1,:) double
end % arguments Output

if size(data,1) == 1 % Only one row, so return it
    sigma = nan(size(data));
    return;
end % if

sigma = std(data, "omitmissing");
end % myStd