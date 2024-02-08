%
% Load in variable(s) from a netCDF file that was generated from Slocum data using dbd2netcdf.
%
% This is a rewrite of various iterations of this script using modern Matlab
%
% Feb-2024, Pat Welch, pat@mousebrains.com

function tbl = osgl_load_glider(fn, fields, t0, t1, qConvertDegMin)
arguments (Input)
    fn string {mustBeFile}
    fields string = missing
    t0 datetime = NaT
    t1 datetime = datetime() + years(1)
    qConvertDegMin = true
end % arguments Input
arguments (Output)
    tbl table
end % arguments Output

stime = tic();

if ismissing(fields)
    a = osgl_read_netCDF(fn); % Load all variables
else
    a = osgl_read_netCDF(fn, fields); % Load without CF conventions
end % if

a = rmfield(a, ["uniqueID", "fn"]);

names = string(fieldnames(a)); % variable names loaded
a = rmfield(a, names(startsWith(names, "hdr_"))); % Drop hdr fields

names = ["m_present_time", "sci_ctd41cp_timestamp", "sci_m_present_time"];
q = ismember(names, fieldnames(a));
if ~any(q)
    error("No time found for %s, %s", fn, fields);
end % if

tbl = table();
tName = names(find(q, 1));
tbl.time = datetime(a.(tName), "ConvertFrom", "posixtime");

tbl = horzcat(tbl, struct2table(a));

tbl = tbl(~isnat(tbl.time),:); % Drop bad times
tbl = tbl(tbl.(tName) > 10, :); % Drop times too close to 1970-01-01

if ~ismissing(t0), tbl = tbl(tbl.time >= t0,:); end
if ~ismissing(t1), tbl = tbl(tbl.time <= t1,:); end

[~, ix] = unique(tbl.time); % Unique and ascending
tbl = tbl(ix,:);

if qConvertDegMin % Convert from deg*100+minutes to decimal degrees
    names = string(tbl.Properties.VariableNames);
    for name = names(endsWith(names, "_lat") | endsWith(names, "_lon"))
        tbl.(name) = osgl_mkDegrees(tbl.(name));
    end % for
end % if

fprintf("Took %.2f seconds to load %s\n", toc(stime), fn);
end % osgl_load_glider