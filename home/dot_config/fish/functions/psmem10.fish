function psmem10
    ps aux | begin
        read -l header
        printf '%s\n' "$header"
        sort -nrk 4 | head -n 10
    end
end
