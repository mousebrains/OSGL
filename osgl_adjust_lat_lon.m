% This is an updated version of my GPS adjust code.
% 
% It find the dead reckoned position just before a valid GPS fix
% then finds the DR and GPS position error, then applies a linear
% in time correction to the DR so they match the GPS fixes at the
% start end.
%
% N.B. This ignores surface drift from the last GPS fix before diving and
%      the first GPS fix after surfacing. This is typically a <100m correction.
%      Typical drift times are ~1minute.
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

function [lat, lon] = osgl_adjust_lat_lon(flt, qDegMin)
arguments (Input)
    flt table
    qDegMin logical = true
end % arguments Input
arguments (Output)
    lat (:,1) double
    lon (:,1) double
end % arguments Output

[~, ix] = unique(flt.m_present_time); % Unique times, including NaN;
ix = ix(flt.m_present_time(ix) > 10); % drop NaN and times <= 10 (1970-01-01T00:00:10Z)
ix = ix(flt.m_present_time(ix) < posixtime(datetime() + years(1))); % Drop >=now+1year

% unique sorted, and within sane time ranges
% We can also map a back to flt via ix!!!!
a = flt(ix,["m_present_time", "m_lat", "m_lon", "m_gps_lat", "m_gps_lon", "m_gps_status"]);
a.t = datetime(a.m_present_time, "ConvertFrom", "posixtime"); % There should be no nat values given constraints

if qDegMin
    for name = ["m_lat", "m_lon", "m_gps_lat", "m_gps_lon"]
        a.(name) = osgl_mkDegrees(a.(name));
    end % for name
end % if qDegMin

gps = a(a.m_gps_status == 0 & abs(a.m_gps_lat) <= 90 & abs(a.m_gps_lon) <= 180, ["t", "m_gps_lat", "m_gps_lon"]);
gps.t0 = [NaT; gps.t(1:end-1)]; % Previous valid GPS fix time
gps.dt = seconds(gps.t - gps.t0); % Time between valid GPS fixes in seconds

a.t0 = interp1(gps.t, gps.t0, a.t, "previous", "extrap"); % Previous GPS fix time
a.dt = seconds(a.t - a.t0); % Time from previous GPS fix in seconds

dr = a(abs(a.m_lat) <= 90 & abs(a.m_lon) <= 180, ["t", "m_lat", "m_lon"]); % Valid dead reckoned rows

gps.lat = interp1(dr.t(2:end), dr.m_lat(1:end-1), gps.t, "previous", "extrap"); % Previous valid DR lat
gps.lon = interp1(dr.t(2:end), dr.m_lon(1:end-1), gps.t, "previous", "extrap"); % Previous valid DR lon

gps.dLatdt = (gps.m_gps_lat - gps.lat) ./ gps.dt; % Rate of change from DR to GPS fix
gps.dLondt = (gps.m_gps_lon - gps.lon) ./ gps.dt;

a.dLatdt = interp1(gps.t, gps.dLatdt, a.t, "next", "extrap"); % rate of change for each DR time
a.dLondt = interp1(gps.t, gps.dLondt, a.t, "next", "extrap");

q = ~isnan(a.m_gps_lat); % No adjustment to m_lat/lon when at a valid GPS fix
a.dLatdt(q) = 0;
a.dLondt(q) = 0;

a.lat = a.m_lat + a.dLatdt .* a.dt;
a.lon = a.m_lon + a.dLondt .* a.dt;

lat = nan(size(flt,1),1);
lon = nan(size(flt,1),1);
lat(ix) = a.lat;
lon(ix) = a.lon;

% Now interpolate nans linearly between timestamps
qMissing = isnan(a.lat) | isnan(a.lon);
qOkay = ~qMissing;

lat(qMissing) = interp1(flt.t(qOkay), lat(qOkay), flt.t(qMissing), "linear");
lon(qMissing) = interp1(flt.t(qOkay), lon(qOkay), flt.t(qMissing), "linear");
end % osgl_adjust_lat_lon