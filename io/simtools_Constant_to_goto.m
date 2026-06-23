function simtools_Constant_to_goto(varargin)
% simtools_Constant_to_goto - 将选中的Constant模块替换为Goto/From模式
% 
% 语法:
%   simtools_Constant_to_goto()           % 自动转换当前选中的Constant模块
%   simtools_Constant_to_goto(block_paths) % 转换指定的模块
%
% 功能说明:
%   1. 自动获取当前Simulink模型中选中的Constant模块
%   2. 为每个选中的Constant创建对应的Goto和From模块
%   3. Constant模块被替换为From模块，From模块连接到Goto模块
%   4. 保持原有信号流不变
%   5. 验证连接是否完整

% ==================== 配置参数 ====================
% 模块尺寸配置（可以根据需要调整）
CONFIG.BLOCK_WIDTH = 80;          % 模块宽度（默认80）
CONFIG.BLOCK_HEIGHT = 30;         % 模块高度（默认30）
CONFIG.SPACING = 50;              % 模块之间的间距
CONFIG.GOTO_PREFIX = '|Goto';     % Goto模块后缀
CONFIG.FROM_PREFIX = '|From';     % From模块后缀
CONFIG.CONST_PREFIX = '|const';   % Constant模块后缀
CONFIG.TAG_VISIBILITY = 'global'; % 标签可见性：'global' 或 'scoped'
CONFIG.AUTO_ARRANGE = true;       % 是否自动整理布局
CONFIG.SHOW_PROGRESS = true;      % 是否显示进度条
CONFIG.MAX_DISPLAY_NAMES = 10;    % 对话框中最多显示多少个模块名
CONFIG.VERIFY_CONNECTIONS = true; % 是否验证连接完整性
% =================================================

%% 获取要转换的模块列表
if nargin == 0
    % 自动获取当前选中的模块
    try
        % 获取当前系统
        current_system = gcs;
        if isempty(current_system)
            errordlg('请先打开一个Simulink模型！', '错误');
            return;
        end
        
        % 获取所有Constant模块并检查哪些被选中
        all_constants = find_system(current_system, 'BlockType', 'Constant');
        
        % 检查哪些被选中
        block_paths = {};
        for i = 1:length(all_constants)
            block = all_constants{i};
            try
                is_selected = get_param(block, 'Selected');
                if strcmp(is_selected, 'on')
                    block_paths{end+1} = block;
                end
            catch
                % 如果Selected属性不支持，使用备选方法
                try
                    if ishandle(block)
                        block_handle = get_param(block, 'Handle');
                        if strcmp(get(block_handle, 'Selected'), 'on')
                            block_paths{end+1} = block;
                        end
                    end
                catch
                    % 如果都不支持，继续
                end
            end
        end
        
        % 如果没找到选中的Constant，提示用户
        if isempty(block_paths)
            uiwait(msgbox('未找到选中的Constant模块！请在模型中选中至少一个Constant模块后重试。', '提示', 'warn'));
            return;
        end
        
        % 构建显示信息
        msg = sprintf('找到 %d 个选中的Constant模块：\n\n', length(block_paths));
        for i = 1:min(length(block_paths), CONFIG.MAX_DISPLAY_NAMES)
            [~, block_name] = fileparts(block_paths{i});
            msg = sprintf('%s  %d. %s\n', msg, i, block_name);
        end
        if length(block_paths) > CONFIG.MAX_DISPLAY_NAMES
            msg = sprintf('%s  ... 还有 %d 个模块\n', msg, length(block_paths) - CONFIG.MAX_DISPLAY_NAMES);
        end
        msg = sprintf('%s\n是否继续转换这些模块？', msg);
        
        % 弹出确认对话框
        choice = questdlg(msg, '确认转换', '是', '否', '是');
        
        % 处理用户选择
        if ~strcmp(choice, '是')
            uiwait(msgbox('已取消操作。', '提示', 'help'));
            return;
        end
        
    catch ME
        % 如果自动获取失败，提供备选方案
        errordlg(sprintf('自动获取选中模块失败：\n%s\n\n请尝试手动指定模块路径。', ME.message), '错误');
        return;
    end
else
    % 使用传入的模块路径
    block_paths = varargin{1};
    if ischar(block_paths)
        block_paths = {block_paths};
    elseif ~iscell(block_paths)
        errordlg('输入参数必须是字符串或字符串元胞数组！', '错误');
        return;
    end
    
    % 确认转换
    msg = sprintf('找到 %d 个指定模块待转换：\n\n', length(block_paths));
    for i = 1:min(length(block_paths), CONFIG.MAX_DISPLAY_NAMES)
        [~, block_name] = fileparts(block_paths{i});
        msg = sprintf('%s  %d. %s\n', msg, i, block_name);
    end
    if length(block_paths) > CONFIG.MAX_DISPLAY_NAMES
        msg = sprintf('%s  ... 还有 %d 个模块\n', msg, length(block_paths) - CONFIG.MAX_DISPLAY_NAMES);
    end
    msg = sprintf('%s\n是否继续转换这些模块？', msg);
    
    choice = questdlg(msg, '确认转换', '是', '否', '是');
    if ~strcmp(choice, '是')
        uiwait(msgbox('已取消操作。', '提示', 'help'));
        return;
    end
end

%% 检查是否存在命名冲突
fprintf('\n正在检查命名冲突...\n');
conflict_blocks = {};
for i = 1:length(block_paths)
    current_block = block_paths{i};
    try
        parent_system = get_param(current_block, 'Parent');
        block_name = get_param(current_block, 'Name');
        
        % 检查可能冲突的模块名
        goto_name = [block_name CONFIG.GOTO_PREFIX];
        from_name = [block_name CONFIG.FROM_PREFIX];
        const_name = [block_name CONFIG.CONST_PREFIX];
        
        if exist_block(parent_system, goto_name)
            conflict_blocks{end+1} = [block_name ' -> ' goto_name ' (已存在)'];
        end
        if exist_block(parent_system, from_name)
            conflict_blocks{end+1} = [block_name ' -> ' from_name ' (已存在)'];
        end
        if exist_block(parent_system, const_name)
            conflict_blocks{end+1} = [block_name ' -> ' const_name ' (已存在)'];
        end
    catch
        % 忽略
    end
end

if ~isempty(conflict_blocks)
    msg = '发现以下命名冲突：\n\n';
    for i = 1:min(length(conflict_blocks), 10)
        msg = sprintf('%s  %s\n', msg, conflict_blocks{i});
    end
    if length(conflict_blocks) > 10
        msg = sprintf('%s  ... 还有 %d 个冲突\n', msg, length(conflict_blocks) - 10);
    end
    msg = sprintf('%s\n\n程序将自动添加数字后缀解决冲突。', msg);
    uiwait(warndlg(msg, '命名冲突警告'));
end

%% 主循环 - 转换每个模块
success_count = 0;
fail_count = 0;
verification_results = struct();

% 创建进度条
if CONFIG.SHOW_PROGRESS
    hWaitBar = waitbar(0, '正在转换Constant模块...', 'Name', '转换进度');
end

for i = 1:length(block_paths)
    current_block = block_paths{i};
    
    % 更新进度条
    if CONFIG.SHOW_PROGRESS && ishandle(hWaitBar)
        waitbar(i/length(block_paths), hWaitBar, ...
            sprintf('正在转换模块 %d/%d: %s', i, length(block_paths), current_block));
    end
    
    try
        % 检查模块是否存在
        try
            get_param(current_block, 'Handle');
        catch
            warning('模块 %s 不存在，跳过！', current_block);
            fail_count = fail_count + 1;
            continue;
        end
        
        % 检查模块是否是Constant类型
        block_type = get_param(current_block, 'BlockType');
        if ~strcmp(block_type, 'Constant')
            warning('模块 %s 不是Constant类型（实际为 %s），跳过！', current_block, block_type);
            fail_count = fail_count + 1;
            continue;
        end
        
        % 获取模块信息
        parent_system = get_param(current_block, 'Parent');
        block_name = get_param(current_block, 'Name');
        constant_value = get_param(current_block, 'Value');
        block_position = get_param(current_block, 'Position');
        
        fprintf('\n--- 转换模块: %s ---\n', block_name);
        
        %% 步骤1：保存原Constant模块的所有连接信息
        port_handles = get_param(current_block, 'PortHandles');
        outport = port_handles.Outport(1);
        line = get_param(outport, 'Line');
        
        % 保存所有目标端口信息
        dst_ports = [];
        dst_block_paths = {};
        dst_port_numbers = {};
        dst_block_names = {};
        dst_line_handles = [];
        
        if line ~= -1
            % 获取所有目标端口
            dst_handles = get_param(line, 'DstPortHandle');
            if iscell(dst_handles)
                dst_handles = [dst_handles{:}];
            end
            
            % 保存原始线路句柄
            dst_line_handles = line;
            
            if ~isempty(dst_handles)
                for j = 1:length(dst_handles)
                    try
                        dst_port = dst_handles(j);
                        if ishandle(dst_port) && dst_port ~= -1
                            dst_ports = [dst_ports, dst_port];
                            dst_block = get_param(dst_port, 'Parent');
                            dst_block_paths{end+1} = getfullname(dst_block);
                            dst_port_numbers{end+1} = get_param(dst_port, 'PortNumber');
                            dst_block_names{end+1} = get_param(dst_block, 'Name');
                        end
                    catch
                        % 如果获取失败，跳过
                    end
                end
            end
        end
        
        expected_connections = length(dst_block_paths);
        fprintf('原始连接: %d 个后续模块\n', expected_connections);
        if expected_connections > 0
            for k = 1:length(dst_block_names)
                fprintf('  -> %s (端口 %d)\n', dst_block_names{k}, dst_port_numbers{k});
            end
        else
            fprintf('  (无后续连接)\n');
        end
        
        %% 步骤2：删除原Constant模块的输出线（关键步骤！）
        if line ~= -1
            try
                delete_line(line);
                fprintf('  ✓ 已删除原始连接线\n');
            catch ME
                fprintf('  ⚠ 删除原始连接线失败：%s\n', ME.message);
            end
        end
        
        % 生成标签名
        goto_tag = block_name;
        
        % 检查并生成不重复的模块名（自动解决冲突）
        goto_name = [block_name CONFIG.GOTO_PREFIX];
        from_name = [block_name CONFIG.FROM_PREFIX];
        const_name = [block_name CONFIG.CONST_PREFIX];
        
        % 如果同名已存在，添加数字后缀
        counter = 1;
        temp_goto_name = goto_name;
        while exist_block(parent_system, temp_goto_name)
            temp_goto_name = sprintf('%s%s_%d', block_name, CONFIG.GOTO_PREFIX, counter);
            counter = counter + 1;
        end
        goto_name = temp_goto_name;
        
        counter = 1;
        temp_from_name = from_name;
        while exist_block(parent_system, temp_from_name)
            temp_from_name = sprintf('%s%s_%d', block_name, CONFIG.FROM_PREFIX, counter);
            counter = counter + 1;
        end
        from_name = temp_from_name;
        
        counter = 1;
        temp_const_name = const_name;
        while exist_block(parent_system, temp_const_name)
            temp_const_name = sprintf('%s%s_%d', block_name, CONFIG.CONST_PREFIX, counter);
            counter = counter + 1;
        end
        const_name = temp_const_name;
        
        %% 计算模块尺寸（根据名字长度自动调整宽度）
        max_name_length = max([length(goto_name), length(from_name), length(const_name)]);
        adjusted_width = max(CONFIG.BLOCK_WIDTH, max_name_length * 7 + 20);
        adjusted_height = CONFIG.BLOCK_HEIGHT;
        if max_name_length > 15
            adjusted_height = CONFIG.BLOCK_HEIGHT + 10;
        end
        
        orig_center_y = (block_position(2) + block_position(4)) / 2;
        
        %% 步骤3：创建Goto模块
        goto_position = [block_position(1) - adjusted_width - CONFIG.SPACING, ...
                        orig_center_y - adjusted_height/2, ...
                        block_position(1) - CONFIG.SPACING, ...
                        orig_center_y + adjusted_height/2];
        
        goto_block = [parent_system '/' goto_name];
        add_block('simulink/Signal Routing/Goto', goto_block, ...
            'Position', goto_position, ...
            'GotoTag', goto_tag, ...
            'TagVisibility', CONFIG.TAG_VISIBILITY);
        
        %% 步骤4：创建新的Constant模块（作为Goto的输入）
        const_position = [goto_position(1) - adjusted_width - CONFIG.SPACING, ...
                         orig_center_y - adjusted_height/2, ...
                         goto_position(1) - CONFIG.SPACING, ...
                         orig_center_y + adjusted_height/2];
        const_block = [parent_system '/' const_name];
        add_block('simulink/Sources/Constant', const_block, ...
            'Position', const_position, ...
            'Value', constant_value);
        
        %% 步骤5：创建From模块（在原Constant位置）
        from_position = [block_position(1), ...
                        orig_center_y - adjusted_height/2, ...
                        block_position(1) + adjusted_width, ...
                        orig_center_y + adjusted_height/2];
        from_block = [parent_system '/' from_name];
        add_block('simulink/Signal Routing/From', from_block, ...
            'Position', from_position, ...
            'GotoTag', goto_tag);
        
        %% 步骤6：连接Constant -> Goto
        const_port = get_param(const_block, 'PortHandles');
        const_out = const_port.Outport(1);
        goto_port = get_param(goto_block, 'PortHandles');
        goto_in = goto_port.Inport(1);
        add_line(parent_system, const_out, goto_in);
        fprintf('  ✓ 连接: Constant -> Goto\n');
        
        %% 步骤7：连接From -> 原来的后续模块（使用保存的端口信息）
        from_port = get_param(from_block, 'PortHandles');
        from_out = from_port.Outport(1);
        
        connected_count = 0;
        if ~isempty(dst_ports)
            fprintf('  正在重新连接后续模块...\n');
            for j = 1:length(dst_ports)
                try
                    % 检查目标模块是否还存在
                    if j <= length(dst_block_paths)
                        dst_block_path = dst_block_paths{j};
                        try
                            get_param(dst_block_path, 'Handle');
                            block_exists = true;
                        catch
                            block_exists = false;
                        end
                        
                        if ~block_exists
                            fprintf('  ✗ 目标模块已不存在: %s\n', dst_block_names{j});
                            continue;
                        end
                        
                        % 重新获取目标模块的端口
                        dst_block_ports = get_param(dst_block_path, 'PortHandles');
                        port_num = dst_port_numbers{j};
                        
                        % 检查输入端口是否存在
                        if isfield(dst_block_ports, 'Inport') && ...
                           ~isempty(dst_block_ports.Inport) && ...
                           port_num <= length(dst_block_ports.Inport)
                            
                            dst_in = dst_block_ports.Inport(port_num);
                            if ishandle(dst_in) && dst_in ~= -1
                                % 创建新的连接
                                add_line(parent_system, from_out, dst_in);
                                connected_count = connected_count + 1;
                                fprintf('  ✓ 已连接: %s (端口 %d)\n', ...
                                    dst_block_names{j}, port_num);
                            else
                                fprintf('  ✗ 端口无效: %s (端口 %d)\n', ...
                                    dst_block_names{j}, port_num);
                            end
                        else
                            % 如果指定端口不存在，尝试使用第一个可用端口
                            if isfield(dst_block_ports, 'Inport') && ~isempty(dst_block_ports.Inport)
                                dst_in = dst_block_ports.Inport(1);
                                if ishandle(dst_in) && dst_in ~= -1
                                    add_line(parent_system, from_out, dst_in);
                                    connected_count = connected_count + 1;
                                    fprintf('  ✓ 已连接: %s (使用端口 1)\n', ...
                                        dst_block_names{j});
                                end
                            else
                                fprintf('  ✗ 模块无输入端口: %s\n', dst_block_names{j});
                            end
                        end
                    end
                catch ME
                    fprintf('  ✗ 连接失败: %s (端口 %d) - %s\n', ...
                        dst_block_names{j}, dst_port_numbers{j}, ME.message);
                end
            end
        else
            fprintf('  (无后续连接需要恢复)\n');
        end
        
        %% 步骤8：验证连接完整性
        verification_results.(block_name).expected = expected_connections;
        verification_results.(block_name).connected = connected_count;
        verification_results.(block_name).status = (connected_count == expected_connections);
        
        if connected_count == expected_connections
            fprintf('  ✓ 连接验证通过 (%d/%d)\n', connected_count, expected_connections);
        else
            fprintf('  ⚠ 连接验证失败 (%d/%d)\n', connected_count, expected_connections);
            if expected_connections > 0 && connected_count < expected_connections
                fprintf('  ⚠ 请手动检查以下连接：\n');
                for j = 1:length(dst_block_names)
                    if j <= length(dst_ports)
                        fprintf('      - %s (端口 %d)\n', dst_block_names{j}, dst_port_numbers{j});
                    end
                end
            end
        end
        
        %% 步骤9：删除原Constant模块
        delete_block(current_block);
        fprintf('  ✓ 删除原Constant模块\n');
        
        %% 步骤10：自动整理布局
        if CONFIG.AUTO_ARRANGE
            try
                Simulink.BlockDiagram.arrangeSystem(parent_system, ...
                    'Selected', {goto_block, from_block, const_block});
            catch
                % 如果自动整理失败，忽略
            end
        end
        
        success_count = success_count + 1;
        fprintf('✓ 成功转换: %s -> %s\n', block_name, from_name);
        fprintf('--- 转换完成 ---\n\n');
        
    catch ME
        warning('✗ 转换模块 %s 时出错：%s', current_block, ME.message);
        fail_count = fail_count + 1;
        continue;
    end
end

% 关闭进度条
if CONFIG.SHOW_PROGRESS && ishandle(hWaitBar)
    close(hWaitBar);
end

%% 显示连接验证总结
fprintf('\n========================================\n');
fprintf('连接验证总结：\n');
fprintf('========================================\n');

verification_passed = 0;
verification_failed = 0;

if CONFIG.VERIFY_CONNECTIONS
    block_names = fieldnames(verification_results);
    for i = 1:length(block_names)
        block_name = block_names{i};
        result = verification_results.(block_name);
        if result.status
            verification_passed = verification_passed + 1;
            fprintf('  ✓ %s: 连接完整 (%d/%d)\n', block_name, result.connected, result.expected);
        else
            verification_failed = verification_failed + 1;
            fprintf('  ✗ %s: 连接不完整 (%d/%d)\n', block_name, result.connected, result.expected);
        end
    end
    
    fprintf('----------------------------------------\n');
    fprintf('验证通过: %d 个模块\n', verification_passed);
    fprintf('验证失败: %d 个模块\n', verification_failed);
end

%% 显示完成信息
fprintf('========================================\n');
fprintf('转换完成！\n');
fprintf('成功转换: %d 个模块\n', success_count);
fprintf('失败: %d 个模块\n', fail_count);
fprintf('========================================\n');

% 显示完成消息框
if fail_count == 0 && verification_failed == 0
    uiwait(msgbox(sprintf('转换完成！\n成功转换 %d 个模块。\n所有连接验证通过！', success_count), '完成', 'help'));
elseif fail_count == 0 && verification_failed > 0
    uiwait(warndlg(sprintf('转换完成！\n成功转换 %d 个模块。\n但 %d 个模块的连接不完整！\n请检查命令窗口中的详细信息，并手动修复连接。', ...
        success_count, verification_failed), '连接警告'));
else
    uiwait(warndlg(sprintf('转换完成！\n成功转换 %d 个模块\n失败 %d 个模块\n请查看命令窗口了解详情。', ...
        success_count, fail_count), '完成'));
end

end

%% 辅助函数：检查模块是否存在
function exists = exist_block(system, block_name)
    try
        if isempty(block_name)
            get_param(system, 'Handle');
            exists = true;
        else
            get_param([system '/' block_name], 'Handle');
            exists = true;
        end
    catch
        exists = false;
    end
end