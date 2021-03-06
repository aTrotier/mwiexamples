function status = decaes(nthreads, varargin)
%DECAES (DE)composition and (C)omponent (A)nalysis of (E)xponential (S)ignals
% Call out to the DECAES command line tool. The Julia executable 'julia'
% is assumed to be on your system path; if not, modify the 'jl_binary_path'
% variable within this file as appropriate. The DECAES.jl Julia package will
% be installed automatically, if necessary.
% 
% See the online documentation for more information on DECAES:
%   https://jondeuce.github.io/DECAES.jl/dev/
% 
% See the mwiexamples github repository for myelin water imaging examples,
% including sample data:
%   https://github.com/jondeuce/mwiexamples
% 
% If you use DECAES in your research, please cite our work:
%   https://doi.org/10.1016/j.zemedi.2020.04.001
% 
% INPUTS:
%   nthreads:   Number of Julia threads to run analysis on; may be a string
%               or an integer
%   varargin:   Flag-value arguments which will be forwarded to
%               DECAES.jl; all arguments must be strings,
%               numeric values, or arrays of numeric values. For arrays,
%               each element is forwarded as an individual argument
% 
% OUTPUTS:
%   status:     (optional) System call status; see SYSTEM for details
% 
% EXAMPLES:
%   Run DECAES with 4 threads on 'image.nii.gz' using command syntax:
%     * We specify an output folder named 'results' using the '--output'
%       flag; this folder will be created if it does not exist
%     * We pass a binary mask file 'image_mask.mat' using the --mask flag;
%       note that the mask file type need not match the image file type
%     * We specify that both T2 distribution calculation and T2 parts
%       analysis should be performed with the --T2map and --T2part flags
%     * The required arguments echo time, number of T2 bins, T2 Range,
%       small peak window, and middle peak window are set using the --TE,
%       --nT2, --T2Range, --SPWin, and --MPWin flags, respectively
%     * Lastly, we indicate that the regularization parameters should be
%       saved using the --SaveRegParam flag
% 
%       decaes 4 image.nii.gz --output results --mask image_mask.mat --T2map --T2part --TE 7e-3 --nT2 60 --T2Range 10e-3 2.0 --SPWin 10e-3 25e-3 --MPWin 25e-3 200.0e-3 --SaveRegParam
% 
%   Run the same command using function syntax:
% 
%       decaes(4, 'image.nii.gz', '--output', 'results', '--mask', 'image_mask.mat', '--T2map', '--T2part', '--TE', 7e-3, '--nT2', 60, '--T2Range', [10e-3, 2.0], '--SPWin', [10e-3, 25e-3], '--MPWin', [25e-3, 200.0e-3], '--SaveRegParam')
% 
%   Create a settings file called 'settings.txt' containing the settings
%   from the above example (note: only one value or flag per line):
% 
%       image.nii.gz
%       --output
%       results
%       --mask
%       image_mask.mat
%       --T2map
%       --T2part
%       --TE
%       7e-3
%       --nT2
%       60
%       --T2Range
%       10e-3
%       2.0
%       --SPWin
%       10e-3
%       25e-3
%       --MPWin
%       25e-3
%       200.0e-3
%       --SaveRegParam
% 
%   Run the example using the above settings file 'settings.txt':
% 
%       decaes 4 @settings.txt
% 
% DECAES was written by Jonathan Doucette (jdoucette@phas.ubc.ca).
% Original MATLAB implementation is by Thomas Prasloski (tprasloski@gmail.com).

    if nargin < 2
        error('Must specify input image or settings file')
    end
    if nargin < 1
        error('Must specify number of threads');
    end

    try
        % Create temp julia entrypoint script
        jl_script = jl_temp_script;

        % Create system command, forwarding varargin to julia
        jl_binary_path = 'julia';
        jl_binary_args = '--startup-file=no -O3';
        command = [jl_binary_path, ' ', jl_binary_args, ' ', jl_script];
        for ii = 1:numel(varargin)
            arg = varargin{ii};
            if islogical(arg)
                arg = double(arg);
            end
            if ischar(arg)
                command = [command, ' ', arg]; %#ok
            elseif isnumeric(arg) || islogical(arg)
                for jj = 1:numel(arg)
                    command = [command, ' ', num2str(arg(jj))]; %#ok
                end
            else
                error('Optional arguments must be char, logical, or numeric values, or arrays of such values');
            end
        end

        % Call out to julia
        setenv('JULIA_NUM_THREADS', check_nthreads(nthreads));
        [st, ~] = system(command, '-echo');

    catch e
        % Delete temporary script
        if exist(jl_script, 'file') == 2
            delete(jl_script);
        end
        rethrow(e)
    end

    % Return status, if requested
    if nargout > 0
        status = st;
    end

end

function jl_script = jl_temp_script

    % Create temporary helper Julia script
    jl_script = [tempname, '.jl'];
    fid = fopen(jl_script, 'w');
    fprintf(fid, 'import Pkg\n');
    fprintf(fid, 'try\n');
    fprintf(fid, '    @eval using DECAES\n');
    fprintf(fid, 'catch e\n');
    fprintf(fid, '    Pkg.add("DECAES")\n');
    fprintf(fid, '    @eval using DECAES\n');
    fprintf(fid, 'end\n');
    fprintf(fid, 'main()\n');
    fclose(fid);

end

function nthreads = check_nthreads(nthreads)

    if ischar(nthreads)
        % Ensure a string nthreads represents a scalar positive integer
        nthreads_double = str2double(nthreads);
        if nthreads_double <= 0 || nthreads_double ~= round(nthreads_double)
            error('Number of threads must be a positive integer; got %s', nthreads);
        end
    elseif isnumeric(nthreads) && isscalar(nthreads)
        % Ensure scalar positive integer is passed
        if nthreads > 0 && nthreads == round(nthreads)
            nthreads = sprintf('%d', round(nthreads));
        else
            error('Number of threads must be a positive integer; got %s', num2str(nthreads));
        end
    else
        error('Number of threads must be a positive integer char or numeric value')
    end

end
