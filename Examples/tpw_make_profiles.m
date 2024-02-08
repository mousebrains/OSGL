% Example of construct profiles with binned depth data for Slocum data.
%
% Feb-2024, Pat Welch, pat@mousebrains.com

depthBin = 2; % 2 meter depth bins

[myDir, myName] = fileparts(mfilename("fullpath"));

codeDir = fullfile(myDir, ".."); % Where OSGL code is located

dataDir = fullfile(myDir, "../Data");
fnFlt = fullfile(dataDir, "flt.nc");
fnSci = fullfile(dataDir, "sci.nc");

origPath = addpath(codeDir, "-begin"); % Before reference to osgl_ code

try
    if ~exist("prevFlt", "var") || ~isequal(prevFlt, fnFlt) || ~exist("flt", "var") || ~istable(flt)
        stime = tic();
        flt = osgl_load_glider(fnFlt, ...
            ["m_present_time", "m_lat", "m_lon", "m_gps_lat", "m_gps_lon", "m_gps_status"]);
        [flt.lat, flt.lon] = osgl_adjust_lat_lon(flt, false);
        prevFlt = fnFlt;
        fprintf("Took %.2f seconds to make flt from %s\n", toc(stime), fnFlt);
        clear prevSci tt pInfo; % Force rebuilding of sci, tt, pInfo, and profiles
    end % if flt

    if ~exist("prevSci", "var") || ~isequal(prevSci, fnSci) || ~exist("sci", "var") || ~istable(sci)
        stime = tic();
        sci = osgl_load_glider(fnSci, ...
            ["sci_ctd41cp_timestamp", "sci_water_pressure", "sci_water_cond", "sci_water_temp"]);
        % Add fields to sci
        sci.lat = interp1(flt.time, flt.lat, sci.time, "linear", "extrap");
        sci.lon = interp1(flt.time, flt.lon, sci.time, "linear", "extrap");
        % Prune ebd rows without valid pressure or too deep
        sci = osgl_calculate_seawater_properties(sci);
        prevSci = fnSci;
        fprintf("Took %.2f seconds to make sci from %s\n", toc(stime), fnSci);
        clear tt pInfo; % Force rebuilding of tt, pInfo, and profiles
    end % if flt

    if ~exist("tt", "var") || ~istable(tt)
        tt = osgl_dive_climb_times(sci.time, sci.depth, plot=true);
        clear pInfo; % Force rebuilding of pInfo and profiles
    end % if Dive/Climb start/mid/stop times

    if ~exist("pInfo", "var") || ~exist("profiles", "var") || ~istable(pInfo)
        a = sci;
        a.temp = a.sci_water_temp;
        names = string(a.Properties.VariableNames);
        a = removevars(a, names(startsWith(names, "sci_")));
        [pInfo, profiles] = osgl_bin_profiles(a, tt, depthBin);
        clear a; % Clean up after myself
    end % if pInfo

    figure;
    t = tiledlayout(2,1);
    h = gobjects(prod(t.GridSize),1);

    h(1) = nexttile();
    p = pcolor(pInfo.time, profiles.depth, profiles.SP);
    p.EdgeColor = "none";
    axis ij; % Flip y axis direction
    ylabel("Depth (m)");

    h(2) = nexttile();
    scatter(sci.time, sci.depth, 10, sci.SP);
    axis ij;
    grid on;
    ylabel("Depth (m)");
    xlabel("Time (UTC)");

    set(h, "Colormap", parula(2048), "CLim", quantile(profiles.SP(:), [0.01, 0.99]));

    cb = colorbar(h(end));
    cb.Label.String = "Salinity (psu)";
    cb.Direction = "reverse"; % Flip direction warmer to colder
    cb.Layout.Tile = "east";  % Outside of both plots

    linkaxes(h, "xy"); % Pan/Zoom changes are reflected in both plots
    hprop = linkprop(h, "CLim"); % Changes to either colorbar are reflected in the other
catch ME
    disp(getReport(ME));
end % try

path(origPath); % Restore the original path
