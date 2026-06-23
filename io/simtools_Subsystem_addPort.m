function varargout = simtools_Subsystem_addPort()
%==========================================================================
% simtools_Subsystem_addPort
%
% 功能：
%   根据当前选中的 Subsystem，在其父层级创建对应的标准 Inport/Outport，
%   名称与 Subsystem 内部 Inport/Outport 保持一致，并自动连线。
%
% 语法：
%   simtools_Subsystem_addPort()          % 转换当前选中的Subsystem
%   [success, failed] = simtools_Subsystem_addPort()  % 返回成功/失败数量
%
% 输入：
%   无（自动获取当前选中的Subsystem）
%
% 输出（可选）：
%   success - 成功转换的模块数量
%   failed  - 失败的模块数量
%
% MATLAB : R2022b ~ R2025b
%==========================================================================

%% ========================= 用户配置 ===========================
PORT_WIDTH      = 50;          % 端口模块宽度
PORT_HEIGHT     = 15;          % 端口模块高度
PORT_OFFSET_X   = 120;         % 端口与Subsystem的水平间距
PORT_MARGIN_Y   = 15;          % 端口之间的垂直边距
USE_AUTOROUTING = true;        % 是否使用自动布线
SHOW_LOG        = true;        % 是否显示详细日志
SKIP_LIBRARY    = true;        % 是否跳过Library中的模块
%% ============================================================

%% 获取当前选中的模块（兼容所有版本）
selected_blocks = getSelectedBlocks(gcs);

if isempty(selected_blocks)
    errordlg('请至少选择一个Subsystem模块！', '错误');
    if nargout > 0
        varargout{1} = 0;
        varargout{2} = 0;
    end
    return;
end

%% 过滤出Subsystem类型的模块
subsystems = {};
for i = 1:length(selected_blocks)
    block = selected_blocks{i};
    try
        % 检查是否是Subsystem
        if strcmp(get_param(block, 'BlockType'), 'SubSystem')
            % 检查是否在Library中
            if SKIP_LIBRARY
                % 检查模块是否在Library中
                is_library = ~isempty(strfind(get_param(block, 'Parent'), 'lib'));
                if ~is_library
                    subsystems{end+1} = block;
                elseif SHOW_LOG
                    fprintf('跳过Library中的模块: %s\n', block);
                end
            else
                subsystems{end+1} = block;
            end
        elseif SHOW_LOG
            fprintf('跳过非Subsystem模块: %s (%s)\n', block, get_param(block, 'BlockType'));
        end
    catch ME
        warning('检查模块 %s 时出错: %s', block, ME.message);
    end
end

if isempty(subsystems)
    if SHOW_LOG
        fprintf('未找到可用的Subsystem模块！\n');
    end
    if nargout > 0
        varargout{1} = 0;
        varargout{2} = 0;
    end
    return;
end

%% 处理每个Subsystem
success_count = 0;
fail_count = 0;

for k = 1:numel(subsystems)
    try
        createPorts(subsystems{k});
        success_count = success_count + 1;
    catch ME
        warning('转换模块 %s 时失败: %s', subsystems{k}, ME.message);
        fail_count = fail_count + 1;
    end
end

%% 输出结果
fprintf('\n========================================\n');
fprintf('simtools_Subsystem_addPort 完成\n');
fprintf('成功: %d 个模块\n', success_count);
fprintf('失败: %d 个模块\n', fail_count);
fprintf('========================================\n');

if nargout > 0
    varargout{1} = success_count;
    varargout{2} = fail_count;
end

%% ============================================================
function createPorts(subsys)
    % 创建端口的子函数
    
    parent  = get_param(subsys,'Parent');
    subName = get_param(subsys,'Name');
    subPos  = get_param(subsys,'Position');
    
    if SHOW_LOG
        fprintf('\n--- 处理 Subsystem: %s ---\n', subName);
    end
    
    % 获取Subsystem内部的Inport和Outport（按端口号排序）
    inBlocks  = find_system(subsys,'SearchDepth',1,'BlockType','Inport');
    outBlocks = find_system(subsys,'SearchDepth',1,'BlockType','Outport');
    
    inBlocks  = sortByPort(inBlocks);
    outBlocks = sortByPort(outBlocks);
    
    subHeight = subPos(4) - subPos(2);
    
    % 创建输入端口
    nIn = numel(inBlocks);
    if SHOW_LOG && nIn > 0
        fprintf('  Inports: %d\n', nIn);
    end
    
    for i = 1:nIn
        blk  = inBlocks{i};
        name = get_param(blk, 'Name');
        port = getPortNumber(blk);
        
        if isnan(port)
            warning('无法获取端口号，跳过: %s', name);
            continue;
        end
        
        if SHOW_LOG
            fprintf('    %d. %s (端口 %d)\n', i, name, port);
        end
        
        newBlk = [parent '/' name];
        
        % 检查是否已存在同名模块
        if existBlock(newBlk)
            if SHOW_LOG
                fprintf('      模块已存在，跳过: %s\n', name);
            end
            continue;
        end
        
        % 计算位置
        [x1, y1, x2, y2] = calculatePortPosition(subPos, nIn, i, PORT_WIDTH, PORT_HEIGHT, PORT_OFFSET_X, PORT_MARGIN_Y, 'in');
        
        % 创建Inport模块
        add_block('simulink/Sources/In1', newBlk, ...
            'Position', [x1 y1 x2 y2]);
        
        % 连接信号线
        try
            src = [name '/1'];
            dst = [subName '/' num2str(port)];
            if USE_AUTOROUTING
                add_line(parent, src, dst, 'autorouting', 'on');
            else
                add_line(parent, src, dst);
            end
            if SHOW_LOG
                fprintf('      已连接: %s -> %s\n', src, dst);
            end
        catch ME
            warning('连接 %s -> %s 失败: %s', src, dst, ME.message);
        end
    end
    
    % 创建输出端口
    nOut = numel(outBlocks);
    if SHOW_LOG && nOut > 0
        fprintf('  Outports: %d\n', nOut);
    end
    
    for i = 1:nOut
        blk  = outBlocks{i};
        name = get_param(blk, 'Name');
        port = getPortNumber(blk);
        
        if isnan(port)
            warning('无法获取端口号，跳过: %s', name);
            continue;
        end
        
        if SHOW_LOG
            fprintf('    %d. %s (端口 %d)\n', i, name, port);
        end
        
        newBlk = [parent '/' name];
        
        % 检查是否已存在同名模块
        if existBlock(newBlk)
            if SHOW_LOG
                fprintf('      模块已存在，跳过: %s\n', name);
            end
            continue;
        end
        
        % 计算位置
        [x1, y1, x2, y2] = calculatePortPosition(subPos, nOut, i, PORT_WIDTH, PORT_HEIGHT, PORT_OFFSET_X, PORT_MARGIN_Y, 'out');
        
        % 创建Outport模块
        add_block('simulink/Sinks/Out1', newBlk, ...
            'Position', [x1 y1 x2 y2]);
        
        % 连接信号线
        try
            src = [subName '/' num2str(port)];
            dst = [name '/1'];
            if USE_AUTOROUTING
                add_line(parent, src, dst, 'autorouting', 'on');
            else
                add_line(parent, src, dst);
            end
            if SHOW_LOG
                fprintf('      已连接: %s -> %s\n', src, dst);
            end
        catch ME
            warning('连接 %s -> %s 失败: %s', src, dst, ME.message);
        end
    end
    
    if SHOW_LOG
        fprintf('--- 完成: %s ---\n', subName);
    end

end

%% ============================================================
function blocks = sortByPort(blocks)
    % 按端口号排序
    
    if isempty(blocks)
        return;
    end
    
    ports = zeros(numel(blocks), 1);
    
    for i = 1:numel(blocks)
        port = getPortNumber(blocks{i});
        if isnan(port)
            ports(i) = inf;
        else
            ports(i) = port;
        end
    end
    
    [~, idx] = sort(ports);
    blocks = blocks(idx);

end

%% ============================================================
function port = getPortNumber(block)
    % 安全获取端口号
    
    try
        port_str = get_param(block, 'Port');
        port = str2double(port_str);
        if isnan(port)
            % 尝试直接获取数字
            port = get_param(block, 'Port');
            if isnumeric(port)
                port = port(1);
            else
                port = NaN;
            end
        end
    catch
        port = NaN;
    end

end

%% ============================================================
function tf = existBlock(path)
    % 检查模块是否存在
    
    try
        get_param(path, 'Handle');
        tf = true;
    catch
        tf = false;
    end

end

%% ============================================================
function [x1, y1, x2, y2] = calculatePortPosition(subPos, n, index, portWidth, portHeight, offsetX, marginY, type)
    % 计算端口模块位置
    
    centerY = calculateCenterY(subPos, n, index, marginY);
    
    if strcmp(type, 'in')
        x1 = subPos(1) - offsetX;
        x2 = x1 + portWidth;
    else  % 'out'
        x1 = subPos(3) + offsetX;
        x2 = x1 + portWidth;
    end
    
    y1 = round(centerY - portHeight/2);
    y2 = y1 + portHeight;

end

%% ============================================================
function centerY = calculateCenterY(subPos, n, index, marginY)
    % 计算端口的垂直中心位置
    
    if n == 1
        centerY = (subPos(2) + subPos(4)) / 2;
    else
        topY    = subPos(2) + marginY;
        bottomY = subPos(4) - marginY;
        stepY   = (bottomY - topY) / (n - 1);
        centerY = topY + (index - 1) * stepY;
    end

end

%% ============================================================
function selected = getSelectedBlocks(system)
    % 获取当前选中的模块（兼容所有版本）
    
    selected = {};
    
    try
        % 方法1：使用 SelectedBlocks（R2015a+）
        selected_paths = get_param(system, 'SelectedBlocks');
        if ~isempty(selected_paths)
            if iscell(selected_paths)
                selected = selected_paths;
            else
                selected = {selected_paths};
            end
            return;
        end
    catch
        % 方法1失败，尝试方法2
    end
    
    try
        % 方法2：遍历所有模块检查 Selected 属性
        all_blocks = find_system(system, 'SearchDepth', 1);
        for i = 1:length(all_blocks)
            block = all_blocks{i};
            if strcmp(block, system)
                continue;
            end
            try
                if strcmp(get_param(block, 'Selected'), 'on')
                    selected{end+1} = block;
                end
            catch
                % 不支持 Selected 属性，跳过
            end
        end
    catch
        % 方法2失败
    end
    
    % 如果还是没找到，提示用户手动指定
    if isempty(selected)
        warning('无法自动获取选中的模块，请确保在Simulink中选中了Subsystem模块。');
    end

end

end