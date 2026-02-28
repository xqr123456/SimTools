function installSimTools()

    fprintf('\n开始安装 SimTools...\n');

    root = fileparts(mfilename('fullpath'));
    rootSafe = strrep(root,'\','\\');

    versionFile = fullfile(root,'version.txt');
    if exist(versionFile,'file')
        version = strtrim(fileread(versionFile));
    else
        version = 'unknown';
    end

    addpath(genpath(root));
    savepath;

    userStartupDir = userpath;
    if contains(userStartupDir,';')
        userStartupDir = extractBefore(userStartupDir,';');
    end

    userStartupFile = fullfile(userStartupDir,'startup.m');

    if ~exist(userStartupFile,'file')
        fid = fopen(userStartupFile,'w');
        fclose(fid);
    end

    content = fileread(userStartupFile);

    if contains(content,'SimTools_AutoLoad')
        fprintf('SimTools 已安装。\n');
        return;
    end

    fid = fopen(userStartupFile,'a');

    fprintf(fid,'\n%%%% SimTools_AutoLoad\n');
    fprintf(fid,'try\n');
    fprintf(fid,'    root = ''%s'';\n', rootSafe);
    fprintf(fid,'    addpath(genpath(root));\n');
    fprintf(fid,'    rehash toolboxcache;\n');
    fprintf(fid,'    sl_refresh_customizations;\n');
    fprintf(fid,'    versionFile = fullfile(root,''version.txt'');\n');
    fprintf(fid,'    if exist(versionFile,''file'')\n');
    fprintf(fid,'        version = strtrim(fileread(versionFile));\n');
    fprintf(fid,'    else\n');
    fprintf(fid,'        version = ''unknown'';\n');
    fprintf(fid,'    end\n');
    fprintf(fid,'    fprintf(''==================================================\\n'');\n');
    fprintf(fid,'    fprintf(''🚀 SimTools 已加载\\n'');\n');
    fprintf(fid,'    fprintf(''路径: %%s\\n'', root);\n');
    fprintf(fid,'    fprintf(''版本: %%s\\n'', version);\n');
    fprintf(fid,'    fprintf(''==================================================\\n'');\n');
    fprintf(fid,'catch ME\n');
    fprintf(fid,'    warning(''SimTools 启动加载失败: %%s'', ME.message);\n');
    fprintf(fid,'end\n');

    fclose(fid);

    rehash toolboxcache;
    sl_refresh_customizations;

    fprintf('\nSimTools 安装完成 ✅\n\n');

end