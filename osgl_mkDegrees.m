% Convert from deg*100 + minutes format into decimal degree format for latitude and
% longitude
%
% Jan-2012, Pat Welch, pat@mousebrains.com

function degrees = osgl_mkDegrees(b)
arguments (Input)
    b double {mustBeReal mustBeNonempty}
end % arguments Input
arguments (Output)
    degrees double;
end % arguments Output

b(abs(b) > 18000) = nan; % Values like 696969 are tags for no data
fracDeg = rem(b, 100) / 60; % fractional degrees, remainder after dividing by 100 over 60
if any(abs(fracDeg(:)) >= 1), error('Some minute portion of input is >= 60'); end
deg = fix(b/100); % Round towards zero
degrees = deg + fracDeg;
end % osgl_mkDegrees
