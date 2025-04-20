#!/bin/bash

username=$1

if [[ -z "$username" ]]; then
    whiptail --msgbox "Usage: $0 <username>" 8 60
    exit 1
fi

source games/game_functions.sh

USER_ID=$(mysql_query "SELECT user_id FROM users WHERE username = '$username';")

if [[ -z "$USER_ID" ]]; then
    whiptail --msgbox "❌ User '$username' not found." 8 60
    exit 1
fi

play_game() {
    local mode=$1
    local user_id=$2
    local role=$3
    local role_name=$4
    local max_riddles=5

    mysql_query "INSERT IGNORE INTO user_stats (user_id, current_health, max_health, current_role)
                 VALUES ($user_id, 5, 5, '$role');"

    local riddle_ids_result
    if [ "$mode" == "new" ]; then
        reset_game $user_id $role
        riddle_ids_result=$(mysql_query "SELECT riddle_id FROM ${role}_riddles
                                        WHERE riddle_id NOT IN (
                                            SELECT riddle_id FROM user_progress
                                            WHERE user_id = $user_id AND role = '$role'
                                        )
                                        ORDER BY RAND() LIMIT $max_riddles;")
    else
        riddle_ids_result=$(get_unfinished_riddles $user_id $role)
        local remaining=$(get_remaining_riddles_count $user_id $role)
        if [ "$remaining" -gt 0 ]; then
            local new_riddles=$(mysql_query "SELECT riddle_id FROM ${role}_riddles
                                           WHERE riddle_id NOT IN (
                                               SELECT riddle_id FROM user_progress
                                               WHERE user_id = $user_id AND role = '$role'
                                           )
                                           ORDER BY RAND() LIMIT $remaining;")
            riddle_ids_result="$riddle_ids_result"$'\n'"$new_riddles"
        fi
    fi
    RIDDLE_IDS=($(echo "$riddle_ids_result"))

    local HEALTH=$(get_health $user_id)

    for RID in "${RIDDLE_IDS[@]}"; do
        local is_solved=$(mysql_query "SELECT COALESCE(is_solved, 0) FROM user_progress WHERE user_id = $user_id AND riddle_id = $RID AND role = '$role';")
        if [ "${is_solved:-0}" -eq 1 ]; then
            continue
        fi

        local RIDDLE_TEXT=$(mysql_query "SELECT riddle_text FROM ${role}_riddles WHERE riddle_id = $RID;")
        local HINT=$(mysql_query "SELECT hint FROM ${role}_riddles WHERE riddle_id = $RID;")
        local CORRECT_ANSWER=$(mysql_query "SELECT correct_answer FROM ${role}_riddles WHERE riddle_id = $RID;")
        local SCORE_VALUE=$(mysql_query "SELECT score_value FROM ${role}_riddles WHERE riddle_id = $RID;")

        whiptail --title "Riddle" --msgbox "🧩 $RIDDLE_TEXT\n\n💡 Commands: hint, health, score, skip, exit" 12 60
        display_health "$HEALTH"
        local SCORE=$(get_score $user_id $role)
        whiptail --msgbox "📊 Current Score: $SCORE" 6 60

        local ATTEMPTS=0
        local MAX_ATTEMPTS=3

        while (( ATTEMPTS < MAX_ATTEMPTS && HEALTH > 0 )); do
            local prompt_text="Your answer (attempt $((ATTEMPTS+1))/$MAX_ATTEMPTS):"
            local answer_height=3
            local answer_width=50
            local default_answer=""

            ANSWER=$(whiptail --inputbox "$prompt_text" $answer_height $answer_width "$default_answer" 3>&1 1>&2 2>&3)
            local answer_exit_status=$?

            if test "$answer_exit_status" -ne 0; then
                whiptail --msgbox "Action cancelled." 6 60
                continue
            fi

            case "${ANSWER,,}" in
                hint)
                    whiptail --msgbox "$HINT" 8 60
                    continue
                    ;;
                health)
                    whiptail --msgbox "$(display_health "$HEALTH")" 8 60
                    continue
                    ;;
                score)
                    whiptail --msgbox "📊 Current Score: $(get_score $user_id $role)" 6 60
                    continue
                    ;;
                skip)
                    whiptail --msgbox "⏩ Skipping this riddle..." 6 60
                    ((HEALTH--))
                    update_health $user_id "$HEALTH"
                    mysql_query "INSERT INTO user_progress (user_id, riddle_id, riddle_source, is_solved, score, role) VALUES ($user_id, $RID, '$role', FALSE, 0, '$role') ON DUPLICATE KEY UPDATE is_solved = FALSE, score = 0;"
                    break
                    ;;
                exit|quit)
                    whiptail --msgbox "Thanks for playing! Your progress has been saved." 8 60
                    update_health $user_id "$HEALTH"
                    exit 0
                    ;;
                *)
                    ((ATTEMPTS++))

                    if [[ "${ANSWER,,}" == "${CORRECT_ANSWER,,}" ]]; then
                        whiptail --msgbox "✅ Correct! +$SCORE_VALUE points!" 6 60
                        mysql_query "INSERT INTO user_progress (user_id, riddle_id, riddle_source, is_solved, score, role) VALUES ($user_id, $RID, '$role', TRUE, $SCORE_VALUE, '$role') ON DUPLICATE KEY UPDATE is_solved = TRUE, score = $SCORE_VALUE;"
                        local NEW_SCORE=$(get_score $user_id $role)
                        whiptail --msgbox "📊 Total Score: $NEW_SCORE" 6 60
                        break
                    else
                        ((HEALTH--))
                        update_health $user_id "$HEALTH"

                        if (( ATTEMPTS < MAX_ATTEMPTS )); then
                            whiptail --msgbox "❌ Incorrect! Health decreased." 6 60
                        else
                            whiptail --msgbox "🛑 Maximum attempts reached! The correct answer was: $CORRECT_ANSWER" 8 60
                            mysql_query "INSERT INTO user_progress (user_id, riddle_id, riddle_source, is_solved, score, role) VALUES ($user_id, $RID, '$role', FALSE, 0, '$role') ON DUPLICATE KEY UPDATE is_solved = FALSE, score = 0;"
                        fi
                    fi
                    ;;
            esac
        done

        if (( HEALTH <= 0 )); then
            whiptail --msgbox "💀 GAME OVER! You've run out of health. Final Score: $(get_score $user_id $role)" 8 60
            break
        fi
    done

    local FINAL_SCORE=$(get_score $user_id $role)
    mysql_query "INSERT INTO applications (user_id, role, riddle_score, status)
                 VALUES ($user_id, '$role', $FINAL_SCORE, 'pending')
                 ON DUPLICATE KEY UPDATE riddle_score = $FINAL_SCORE, status = 'pending';"

    whiptail --msgbox "🎉 Screening completed! Final Score: $FINAL_SCORE Remaining health: $HEALTH/5" 10 60
    read -p "Press Enter to return to dashboard..."
}

show_menu "$username" "$USER_ID" "$2" "$3"