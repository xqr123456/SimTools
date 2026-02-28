function block = simtools_getSelectedBlock(callbackInfo)

    sel = callbackInfo.getSelection;

    if isempty(sel)
        block = [];
        return;
    end

    block = sel{1};

end