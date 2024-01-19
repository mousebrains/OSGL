% Load data from a netCDF file into a matlab structure.
% If no optional arguments are supplied, all variables with
% a supported data type are loaded.
%
% The optional arguments can be strings or cell arrays of strings,
% which specify the variable names to load.
%
% If a specified variable name does not exist in fn, or is an
% unsupported data type, an error is thrown.
%
% If the variable 'fn' is not loaded, the structure field 'fn' is set to
% the input filename.
%
% Jan-2012, Pat Welch, pat@mousebrains.com
% Jan-2019, Pat Welch, pat@mousebrains.com, switch to low level interface
% for speed reasons

function a = osgl_read_netCDF(fn, names)
arguments (Input)
    fn string {mustBeFile} % Input filename
end % arguments Input
arguments (Input,Repeating)
    names (:,1) string % Optional variable names
end % arguments Repeating
arguments (Output)
    a struct % Output structure of data read from fn
end % arguments output

names = cellfun(@(x) x(:), names, "UniformOutput", false); % Make sure any arrays are in the same orientation
names = string(vertcat(names{:}));

ncid = netcdf.open(fn); % Open the netCDF file
cleanUpObj = onCleanup(@() netcdf.close(ncid)); % In case of errors/warnings/...

if isempty(names)
    [names, varids] = loadNames(ncid);
else
    names = unique(names); % No duplicates
    [names, varids] = getVarIDs(ncid, names);
end % if

a = struct('fn', fn);
n = -1;

for i = 1:numel(names)
    name = names(i);
    try
        item = netcdf.getVar(ncid, varids(i));
        a.(genvarname(name)) = item;
        if isvector(item)
            n = max(n, size(item,1));
        end % if
    catch e
        warning('Error getting %s\n%s', name, getReport(e))
    end % try
end % for i

if ~isfield(a, 'uniqueID') && (n > 0)
    a.uniqueID = uint32(1:n)';
end % if
end % osgl_read_netCDF

function [names, varids] = loadNames(ncid)
arguments (Input)
    ncid double % NetCDF file id from netcdf.open
end % arguments Input
arguments (Output)
    names (:,1) string  % Variable names in NetCDF file
    varids (:,1) double % Variable ids in ncid
end % arguments Output

[~, n] = netcdf.inq(ncid); % Get the number of variables
names = cell(n,1);
varids = zeros(size(names)) - 1;
minxtype = netcdf.getConstant('NC_BYTE');
maxxtype = netcdf.getConstant('NC_STRING');
for i = 1:n
    [varname, xtype] = netcdf.inqVar(ncid, i-1);
    if (xtype >= minxtype) && (xtype <= maxxtype)
        names{i} = varname;
        varids(i) = i-1;
    end % if
end % for i
msk = varids >= 0;
names = string(names(msk));
varids = varids(msk);
end % loadNames

function [names, varids] = getVarIDs(ncid, names)
arguments (Input)
    ncid double % NetCDF file id from netcdf.open
    names (:,1) string  % Variable names to get from the NetCDF file
end % arguments Input
arguments (Output)
    names (:,1) string  % Variable names to get from the NetCDF file
    varids (:,1) double % Variable ids in ncid
end % arguments Output

varids = zeros(size(names));
for i = 1:numel(names)
    varids(i) = netcdf.inqVarID(ncid, names(i));
end % for i
end % getVarIDs
