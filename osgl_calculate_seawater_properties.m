%
% Calculate various seawater properties from the Slocum CTD
%
% This is a consolidation of code snippets into a single location
%
% Feb-2024, Pat Welch, pat@mousebrains.com

function tbl = osgl_calculate_seawater_properties(tbl)
arguments (Input)
    tbl table % Must contain at least sci_water_pressure, sci_water_cond, sci_water_temp, lat, and lon
end % arguments Input
arguments (Output)
    tbl table % Original table plus depth, SP, SA, CT, theta, sigma, and rho
end % arguments Output

pressure = tbl.sci_water_pressure * 10; % bar -> dbar
cond = tbl.sci_water_cond * 10; % S/m -> mS/cm
temp = tbl.sci_water_temp; % C

for name = ["depth", "SP", "SA", "CT", "theta", "sigma", "rho"]
    tbl.(name) = nan(size(pressure));
end % for name

q = ~isnan(pressure) & ~isnan(cond) & ~isnan(temp) ...
    & pressure > -10 & pressure < 10000 ... % sane pressure
    & temp > -5 & temp < 90; % sane temperature

tbl.depth(q) = gsw_depth_from_z(gsw_z_from_p(pressure(q), tbl.lat(q))); % dbar -> meter, >0 deeper
tbl.SP(q)    = gsw_SP_from_C(cond(q), temp(q), pressure(q)); % PSU
tbl.SA(q)    = gsw_SA_from_SP(tbl.SP(q), pressure(q), tbl.lon(q), tbl.lat(q)); % g/kg
tbl.CT(q)    = gsw_CT_from_t(tbl.SA(q), temp(q), pressure(q)); % conservative temperature, C
tbl.theta(q) = gsw_pt_from_CT(tbl.SA(q), tbl.CT(q)); % potential temperature, C
tbl.sigma(q) = gsw_sigma0(tbl.SA(q), tbl.CT(q)); % potential density at 0 bars, kg/m^3 - 1000
tbl.rho(q)   = gsw_rho(tbl.SA(q), tbl.CT(q), pressure(q)) - 1000; % in-situ density kg/m^3 - 1000
end % osgl_calculate_seawater_properties