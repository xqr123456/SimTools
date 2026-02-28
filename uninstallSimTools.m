function uninstallSimTools()

    userStartupFile = fullfile(userpath,'startup.m');

    if ~exist(userStartupFile,'file')
        disp('未找到 startup.m');
        return;
    end

    content = fileread(userStartupFile);

    % 删除自动加载部分
    newContent = regexprep(content,...
        '%%%% SimTools_AutoLoad[\s\S]*?end','');

    fid = fopen(userStartupFile,'w');
    fwrite(fid,newContent);
    fclose(fid);

    disp('SimTools 已卸载');

end