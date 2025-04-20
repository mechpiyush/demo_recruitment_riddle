#!/bin/bash

# Common functions for all game scripts

mysql_query() {
    mysql -sN -e "$1" recruitment_portal2
}

display_health() {
    local health="$1"
    local max_health=5
    local health_bar="["

    for ((i=1; i<=max_health; i++)); do
        if (( i <= health )); then
            health_bar+=" ❤"
        else
            health_bar+=" ♡"
        fi
        ((i < max_health)) && health_bar+=" "
    done

    health_bar+=" ]"
    echo -e "\n\033[1;31mHealth: $health_bar ($health/$max_health)\033[0m"
}

get_health() {
    local health=$(mysql_query "SELECT current_health FROM user_stats WHERE user_id = $1;")
    # Trim any leading/trailing whitespace and ensure only the first line is taken
    echo "$health" | head -n 1 | tr -d '[:space:]'
}

update_health() {
    mysql_query "UPDATE user_stats SET current_health = $2 WHERE user_id = $1;"
}

get_score() {
    local role=$2
    local score=$(mysql_query "SELECT COALESCE(SUM(score), 0) FROM user_progress WHERE user_id = $1 AND role = '$role' AND is_solved = 1;")
    echo "${score:-0}"
}

reset_game() {
    local user_id=$1
    local role=$2
    mysql_query "DELETE FROM user_progress WHERE user_id = $user_id AND role = '$role';"
    mysql_query "UPDATE user_stats SET current_health = 5, current_score = 0 WHERE user_id = $user_id;"
    mysql_query "DELETE FROM applications WHERE user_id = $user_id AND role = '$role';"
    # Reset role-specific score
    case "$role" in
        "software_engineer")
            mysql_query "UPDATE user_stats SET software_engineer_score = 0 WHERE user_id = $user_id;"
            ;;
        "data_scientist")
            mysql_query "UPDATE user_stats SET data_scientist_score = 0 WHERE user_id = $user_id;"
            ;;
        "devops")
            mysql_query "UPDATE user_stats SET devops_score = 0 WHERE user_id = $user_id;"
            ;;
    esac
}

has_unfinished_game() {
    local user_id=$1
    local role=$2
    local count=$(mysql_query "SELECT COUNT(*) FROM user_progress WHERE user_id = $user_id AND role = '$role' AND is_solved = 0;")
    [ "$count" -gt 0 ] && return 0 || return 1
}

get_unfinished_riddles() {
    local user_id=$1
    local role=$2
    mysql_query "SELECT riddle_id FROM user_progress WHERE user_id = $user_id AND role = '$role' AND is_solved = 0;"
}

get_remaining_riddles_count() {
    local user_id=$1
    local role=$2
    local count=$(mysql_query "SELECT COUNT(*) FROM user_progress WHERE user_id = $user_id AND role = '$role';")
    echo $((5 - count))
}

show_menu() {
    local username=$1
    local user_id=$2
    local role=$3
    local role_name=$4
    local height=10
    local width=40
    local choices

    choices=(
        "1" "New Game"
    )
    if has_unfinished_game $user_id $role; then
        choices+=("2" "Continue Game")
    else
        choices+=("2" "Continue Game (no saved game)")
    fi
    choices+=("3" "Back to Dashboard")

    chosen=$(whiptail --clear --title "=== ${role_name} Riddles ===" \
                       --menu "Select an option:" $height $width 3 \
                       "${choices[@]}" 3>&1 1>&2 2>&3)
    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        case "$chosen" in
            "1")
                play_game "new" $user_id $role "$role_name"
                ;;
            "2")
                if has_unfinished_game $user_id $role; then
                    play_game "continue" $user_id $role "$role_name"
                else
                    echo -e "\n\033[1;31mNo saved game found. Starting a new game...\033[0m"
                    sleep 2
                    play_game "new" $user_id $role "$role_name"
                fi
                ;;
            "3")
                exit 0
                ;;
        esac
    fi
}