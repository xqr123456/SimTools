function sl_customization(cm)

    cm.addCustomMenuFcn( ...
        'Simulink:ContextMenu', ...
        @simtools_getMenu);

end


%% 主菜单
function schemaFcns = simtools_getMenu(~)
    schemaFcns = {@simtools_container};
end


%% 容器菜单
function schema = simtools_container(~)

    schema = sl_container_schema;
    schema.label = '🚀 SimTools';
    schema.childrenFcns = {@menu_mapping, @menu_io, @menu_app};

end


%% 子菜单1
function schema = menu_mapping(~)

    schema = sl_action_schema;
    schema.label = '生成 Mapping';
    schema.callback = @(cb) simtools_generateMapping(cb);

end


%% 子菜单2
function schema = menu_io(~)

    schema = sl_action_schema;
    schema.label = '自动添加 IO';
    schema.callback = @(cb) simtools_addIO(cb);

end


%% 子菜单3
function schema = menu_app(~)

    schema = sl_action_schema;
    schema.label = '打开 SimTools App';
    schema.callback = @(cb) simtools_openMainApp();

end