% Fit n gaussians to y = sum_i=1:n amp_i * exp(-0.5 * ((x - mu_i) / sigma_i).^2
%
% One can use the fit function in the Curve Fitting Toolbox, if one has it,
% but this uses nlinfit from the statistics toolbox instead
%
% N.B. The gaussian function her agrees with Matlab's fit, which does not
%      have a 1/2 in the exponential.
%      So the width coefficient is the 2 times sigma in normal gaussians.
%
% Dec-2014, Pat Welch, pat@mousebrains.com

classdef osgl_fit_gaussian
    properties
        x (:,1) double     % Independent variable
        y (:,1) double     % Dependent variable, y = f(x)
        n double;           % Number of Gaussians
        pars (3,:) double  % Parameters 3 parameters by n paraemeters
        resid (:,1) double % Residual of y - f(x)
        sigma (:,:) double % Covariance of parameters
    end % properties

    methods
        function obj = osgl_fit_gaussian(x, y, n) % constructor
            arguments (Input)
                x (:,1) double {mustBeNonempty}
                y (:,1) double {mustBeNonempty}
                n double {mustBeInteger,mustBeInRange(n, 1, 10)} = 1;
            end
            arguments (Output)
                obj osgl_fit_gaussian
            end % arguments Output

            if numel(x) ~= numel(y)
                error('numel(x)(%d) ~= numel(y)(%d)', numel(x), numel(y));
            end

            q = ~isnan(x) | ~isnan(y);
            x = x(q);
            y = y(q);

            if isempty(x)
                error('x and y are empty after taking out joint NaNs');
            end

            obj.x = x;
            obj.y = y;
            obj.n = n;

            pars0 = obj.initPars(x, y, n);

            [obj.pars, obj.resid, ~, obj.sigma] = nlinfit(x, y, @obj.gaussian, pars0);
        end % osgl_fit_gaussian

        function [px, py] = curve(this)
            arguments (Input)
                this osgl_fit_gaussian
            end
            arguments (Output)
                px (:,1) double % sorted unique independent variables
                py (:,1) double % prediction
            end % arguments Output

            px = unique(this.x);
            py = this.gaussian(this.pars, px);
        end % points

        function lab = labels(this)
            arguments (Input)
                this osgl_fit_gaussian
            end
            arguments (Output)
                lab (:,1) string % cell array of labels for each gaussian
            end % arguments Output

            ci = nlparci(this.pars, this.resid, 'covar', this.sigma);
            sig = reshape(diff(ci, [], 2) / 2, 3, []);
           
            if this.n == 1
                lab = sprintf('amp=%.2g\\pm%.2g \\mu=%.2g\\pm%.2g \\sigma=%.2g\\pm%.2g', [this.pars, sig]');
                return;
            end % if n == 1
            
            lab = strings(this.n, 1);
            for i = 1:size(this.pars,2)
                lab(i) = ...
                    sprintf('amp_%d=%.2g\\pm%.2g \\mu_%d=%.3g\\pm%.2g \\sigma_%d=%.2g\\pm%.2g', ...
                    i, this.pars(1,i), sig(1,i), ...
                    i, this.pars(2,i), sig(2,i), ...
                    i, this.pars(3,i), sig(3,i));
            end % for i
        end % labels

        function [this, h] = plot(this, qLegend)
             arguments (Input)
                this osgl_fit_gaussian
                qLegend logical = true % Should a legend be plotted or not
            end
            arguments (Output)
                this osgl_fit_gaussian
                h % Line object
            end % arguments Output

            [px, py] = this.curve();
            colors = hsv(this.n + 2);

            plot(this.x, this.y, '.', 'Color', colors(1,:));
            hold on;
            h = plot(px, py, '-', 'Color', colors(2,:));

            if this.n ~= 1
                h = gobjects(this.n,1);
                for i = 1:size(this.pars,2)
                    py = this.gaussian(this.pars(:,i), px);
                    h(i) = plot(px, py, "-", "Color", colors(i+2,:));
                end
            end % if
            hold off;

            if qLegend
                legend(h, this.labels(), 'Location', 'best', 'box', 'off');
            end % if
        end % plot
    end % methods

    methods (Access = public, Static = true)
        function y = gaussian(p, x)
            arguments (Input)
                p (3,:) double % Parameters 3xn
                x (:,1) double % Independent variable
            end % arguments Input
            arguments (Output)
                y (:,1) double % Prediction
            end % arguments Output

            y = zeros(size(x));
            for i = 1:size(p,2) % Walk through parameters
                amp = p(1,i);
                mu = p(2,i);
                sig = p(3,i);
                y = y + amp .* exp(-((x - mu) ./ sig).^2);
            end % for
        end % gaussian
    end % methods

    methods (Access = private, Static = true)
        function p = initPars(x, y, n) % Find peaks
            arguments (Input)
                x (:,1) double % Independent variable
                y (:,1) double % Dependent variable
                n double % Number of gaussians
            end % arguments Input
            arguments (Output)
                p (3,:) double % Initial parameters
            end % arguments Output

            [x, ix] = unique(x); % Sort and make unique
            y = y(ix);

            nMax = numel(x);

            if nMax < 3
                error('Too few points, %d', nMax);
            end

            p = osgl_fit_gaussian.initParsRecursive(x, y, n);
        end % initPars

        function p = initParsRecursive(x, y, n)
             arguments (Input)
                x (:,1) double % Independent variable
                y (:,1) double % Dependent variable
                n double % Number of gaussians
            end % arguments Input
            arguments (Output)
                p (3,:) double % Initial parameters
            end % arguments Output

            lf = polyfit(x, y, 1); % Take off any linear trend
            y = y - polyval(lf, x);

            if n == 1
                p = zeros(3,n);
                [p(1,1), ix] = max(y);
                p(2,1) = x(ix);
                p(3,1) = osgl_fit_gaussian.fwhm(x, y, ix);
                return;
            end % if

            p0 = osgl_fit_gaussian.initParsRecursive(x, y, n-1);
            p1 = nlinfit(x, y, @osgl_fit_gaussian.gaussian, p0);
            y = y - osgl_fit_gaussian.gaussian(p1, x);
            lf = polyfit(x, y, 1); % Take off residual linear trend
            y = y - polyval(lf, x);
            p = zeros(3,n);
            p(:,1:end-1) = p1;
            [p(1,end), ix] = max(y);
            p(2,end) = x(ix);
            p(3,end) = osgl_fit_gaussian.fwhm(x, y, ix);
        end % initParsRecursive

        function width = fwhm(x, y, iCentroid) % Full Width at Half Max
             arguments (Input)
                x (:,1) double % Independent variable
                y (:,1) double % Dependent variable
                iCentroid
            end % arguments Input
            arguments (Output)
                width
            end % arguments Output
            
            lhs = [];
            rhs = [];

            if iCentroid ~= 1 % Something on left hand side
                [yy, i] = unique(y(1:iCentroid));
                lhs = interp1(yy, x(i), y(iCentroid) / 2, 'linear', 'extrap');
            end % if lhs

            if iCentroid ~= numel(y) % Something on right hand side
                [yy, i] = unique(y(iCentroid:end));
                xx = x(iCentroid:end);
                rhs = interp1(yy, xx(i), y(iCentroid) / 2, 'linear', 'extrap');
            end % if rhs

            if isempty(lhs)
                if (isempty(rhs)) % No data to use, so set to 1
                    width = 1;
                else
                    width = 2 * (rhs - x(iCentroid));
                end
            elseif isempty(rhs)
                width = 2 * (x(iCentroid) - lhs);
            else
                width = rhs - lhs;
            end
        end % fwhm
    end % methods
end % classdef

