if type --query bat
    complete --erase --command cat
    complete --command cat --wraps bat
else
    __source_fish_function cat completions
end
