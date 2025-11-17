export AWS_EC2_PEM_KEY_PATH="~/.config/zsh/environment.zsh"
export PROFILE="mfa"

function ec2-ssh() {
    local regions=(
        "ap-northeast-2 (서울, Seoul)"
        "us-east-1 (북부 버지니아, N. Virginia)"
        "eu-west-2 (런던, London)"
        "eu-north-1 (스톡홀름, Stockholm)"
        "us-west-2 (오리건, Oregon)"
        "sa-east-1 (상파울루, São Paulo)"
    )
      local name_filter="project"

    local selected_region_display
    selected_region_display=$(printf "%s\n" "${regions[@]}" | fzf --prompt="Select AWS Region > ")
    if [[ -z "$selected_region_display" ]]; then
        echo "No region selected."
        return 1
    fi
    local selected_region_code="${selected_region_display%% *}"

    local instance_info
    instance_info=$( \
        aws ec2 describe-instances --profile "$PROFILE" --region "$selected_region_code" \
            --filters "Name=tag:Name,Values=*${name_filter}*" "Name=instance-state-name,Values=running" \
            --query 'Reservations[].Instances[].[InstanceId, PublicIpAddress, PrivateIpAddress, InstanceType, Tags[?Key==`Name`]|[0].Value, State.Name]' \
            --output text \
        | fzf --prompt="Select EC2 in [$selected_region_display] > " --header="ID | Public IP | Private IP | Type | Name | State"
    )

    if [[ -n "$instance_info" ]]; then
        local instance_ip
        instance_ip=$(echo "$instance_info" | awk -F'	' '{print $2}')
        local instance_name
        instance_name=$(echo "$instance_info" | awk -F'	' '{print $5}')

        if [[ -z "$instance_ip" || "$instance_ip" == "None" ]]; then
            echo "Selected instance has no public IP. Cannot SSH."
            return 1
        fi

        echo "Connecting to $instance_name at $instance_ip..."
        ssh -o StrictHostKeyChecking=no -i "$AWS_EC2_PEM_KEY_PATH" "ec2-user@$instance_ip"
    else
        echo "No instance selected."
    fi
}

function ec2-ssh-all() {
    local name_filter="project"
    echo "🌎 Querying all AWS regions for running '${name_filter}' instances... (This may take 10-20 seconds...)"

    local all_regions=("${(@f)$(aws ec2 describe-regions --query "Regions[].RegionName" --output text --profile "$PROFILE" | tr '\t' '\n')}")
    if [[ ${#all_regions[@]} -eq 0 ]]; then
        echo "Error: Could not retrieve AWS region list."
        return 1
    fi

    local instance_list
    instance_list=$( \
        for region in "${all_regions[@]}"; do
            (
                aws ec2 describe-instances --profile "$PROFILE" --region "$region" \
                    --filters "Name=tag:Name,Values=*${name_filter}*" "Name=instance-state-name,Values=running" \
                    --query 'Reservations[].Instances[].[InstanceId, PublicIpAddress, PrivateIpAddress, InstanceType, Tags[?Key==`Name`]|[0].Value, State.Name, Placement.AvailabilityZone]' \
                    --output text
            ) &
        done
        wait
    )

    if [[ -z "$instance_list" ]]; then
        echo "No running 'aicreation' instances found in any region."
        return 1
    fi

    local display_list
    display_list=$(echo "$instance_list" | awk -F'	' '{
        az=$7;
        region=az; sub(/[a-z]$/, "", region);
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", region, $1, $2, $3, $4, $5, $6
    }')

    local selected_instance
    selected_instance=$(echo "$display_list" | fzf --prompt="Select EC2 Instance (All Regions) > " --header="Region | ID | Public IP | Private IP | Type | Name | State")

    if [[ -n "$selected_instance" ]]; then
        local instance_ip
        instance_ip=$(echo "$selected_instance" | awk -F'	' '{print $3}')
        local instance_name
        instance_name=$(echo "$selected_instance" | awk -F'	' '{print $6}')

        if [[ -z "$instance_ip" || "$instance_ip" == "None" ]]; then
            echo "Selected instance has no public IP. Cannot SSH."
            return 1
        fi

        echo "Connecting to $instance_name at $instance_ip..."
        ssh -o StrictHostKeyChecking=no -i "$AWS_EC2_PEM_KEY_PATH" "ec2-user@$instance_ip"
    else
        echo "No instance selected."
    fi
}
