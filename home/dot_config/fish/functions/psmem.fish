function psmem -a count -d "List processes by memory use, or only the top count"
    ps aux | begin
        read -l header
        printf '%s\n' "$header"
        if set -q count[1]
            sort -nrk 4 | head -n $count
        else
            sort -nrk 4
        end
    end
end
