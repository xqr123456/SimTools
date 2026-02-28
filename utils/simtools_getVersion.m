function version = simtools_getVersion()

    root = fileparts(mfilename('fullpath'));
    root = fileparts(root);
    root = fileparts(root);

    versionFile = fullfile(root,'version.txt');

    if exist(versionFile,'file')
        version = strtrim(fileread(versionFile));
    else
        version = 'unknown';
    end

end