% This is an updated version of my GPS adjust code.
% It relies on the fact that the previous m_lat/lon
% from a new GPS fix is unadjusted.
%
% Inputs:
%   tbl.m_present_time is a posix timestamp
%   tbl.m_gps_lat is the GPS fix's latitude
%   tbl.m_gps_lon is the GPS fix's longitude
%   tbl.m_gps_status is zero for good GPS fixes
%   tbl.m_lat is the glider's dead reckoned latitude, updated with each new GPS fix
%   tbl.m_lon is the glider's dead reckoned longitude, updated with each new GPS fix
%   qDegMin is logical, true if the m_*lat/lon are in deg*100+min else decimal degrees
%
% Outputs:
%   lat is the adjusted decimal degree latitude
%   lon is the adjusted decimal degree longitude
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function [lat, lon] = osgl_adjust_lat_lon(tbl, qDegMin)
arguments (Input)
    tbl table
    qDegMin logical = true
end % arguments Input
arguments (Output)
    lat (:,1) double
    lon (:,1) double
end % arguments Output

[~, ix] = unique(tbl.m_present_time); % Unique times, including NaN;
ix = ix(tbl.m_present_time(ix) > 0); % drop NaN and times <= 0
a = tbl(ix,:); % Non Nan and unique sorted

q = a.m_gps_status ~= 0; % Bad GPS fixes, set to NaN
a.m_gps_lat(q) = nan;
a.m_gps_lon(q) = nan;

if qDegMin
    a.m_lat = osgl_mkDegrees(a.m_lat);
    a.m_lon = osgl_mkDegrees(a.m_lon);
    a.m_gps_lat = osgl_mkDegrees(a.m_gps_lat);
    a.m_gps_lon = osgl_mkDegrees(a.m_gps_lon);
end % if qDegMin

a.t = datetime(a.m_present_time, "ConvertFrom", "posixtime");

gps = a(~isnan(a.m_gps_lat),:); % Good GPS fixes
gps.t0 = [NaT; gps.t(1:end-1)]; % Previous valid GPS fix time
gps.dt = seconds(gps.t - gps.t0);

a.t0 = interp1(gps.t, gps.t0, a.t, "previous", "extrap");
a.dt = seconds(a.t - a.t0);

b = a(~isnan(a.m_lat),:); % Valid m_lat/lon
gps.lat = interp1(b.t(2:end), b.m_lat(1:end-1), gps.t, "previous", "extrap");
gps.lon = interp1(b.t(2:end), b.m_lon(1:end-1), gps.t, "previous", "extrap");
gps.dLatdt = (gps.m_gps_lat - gps.lat) ./ gps.dt;
gps.dLondt = (gps.m_gps_lon - gps.lon) ./ gps.dt;

a.dLatdt = interp1(gps.t, gps.dLatdt, a.t, "next", "extrap");
a.dLondt = interp1(gps.t, gps.dLondt, a.t, "next", "extrap");

q = ~isnan(a.m_gps_lat);
a.dLatdt(q) = 0;
a.dLondt(q) = 0;

a.lat = a.m_lat + a.dLatdt .* a.dt;
a.lon = a.m_lon + a.dLondt .* a.dt;

lat = nan(size(tbl,1),1);
lon = nan(size(tbl,1),1);
lat(ix) = a.lat;
lon(ix) = a.lon;
end % osgl_adjust_lat_lon