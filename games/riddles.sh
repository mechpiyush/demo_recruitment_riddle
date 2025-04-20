#!/bin/bash

username=$1

if [[ -z "$username" ]]; then
    echo "Usage: $0 <username>"
    exit 1
fi

source games/game_functions.sh

USER_ID=$(mysql_query "SELECT user_id FROM users WHERE username = '$username';")

if [[ -z "$USER_ID" ]]; then
    echo "❌ User '$username' not found."
    exit 1
fi

play_game() {
    local mode=$1
    local user_id=$2
    local role=$3
    local role_name=$4
    
    mysql_query "INSERT IGNORE INTO user_stats (user_id, current_health, max_health, current_role)
                 VALUES ($user_id, 5, 5, '$role');"

    if [ "$mode" == "new" ]; then
        reset_game $user_id $role
        RIDDLE_IDS=($(mysql_query "SELECT riddle_id FROM ${role}_riddles 
                                  WHERE riddle_id NOT IN (
                                      SELECT riddle_id FROM user_progress 
                                      WHERE user_id = $user_id AND role = '$role'
                                  )
                                  ORDER BY RAND() LIMIT 5;"))
    else
        RIDDLE_IDS=($(get_unfinished_riddles $user_id $role))
        remaining=$(get_remaining_riddles_count $user_id $role)
        if [ "$remaining" -gt 0 ]; then
            new_riddles=($(mysql_query "SELECT riddle_id FROM ${role}_riddles 
                                      WHERE riddle_id NOT IN (
                                          SELECT riddle_id FROM user_progress 
                                          WHERE user_id = $user_id AND role = '$role'
                                      )
                                      ORDER BY RAND() LIMIT $remaining;"))
            RIDDLE_IDS+=("${new_riddles[@]}")
        fi
    fi

    HEALTH=$(get_health $user_id)

    for RID in "${RIDDLE_IDS[@]}"; do
        is_solved=$(mysql_query "SELECT COALESCE(is_solved, 0) FROM user_progress WHERE user_id = $user_id AND riddle_id = $RID AND role = '$role';")
        if [ "${is_solved:-0}" -eq 1 ]; then
            continue
        fi

        RIDDLE_TEXT=$(mysql_query "SELECT riddle_text FROM ${role}_riddles WHERE riddle_id = $RID;")
        HINT=$(mysql_query "SELECT hint FROM ${role}_riddles WHERE riddle_id = $RID;")
        CORRECT_ANSWER=$(mysql_query "SELECT correct_answer FROM ${role}_riddles WHERE riddle_id = $RID;")
        SCORE_VALUE=$(mysql_query "SELECT score_value FROM ${role}_riddles WHERE riddle_id = $RID;")

        echo -e "\n\033[1;36m========== Riddle ==========\033[0m"
        echo -e "🧩 $RIDDLE_TEXT"
        echo -e "\n💡 \033[3m(Commands: 'hint', 'health', 'score', 'skip', 'exit')\033[0m"
        display_health "$HEALTH"
        SCORE=$(get_score $user_id $role)
        echo -e "📊 \033[1;33mCurrent Score:\033[0m $SCORE"

        ATTEMPTS=0
        MAX_ATTEMPTS=3

        while (( ATTEMPTS < MAX_ATTEMPTS && HEALTH > 0 )); do
            read -p "Your answer (attempt $((ATTEMPTS+1))/$MAX_ATTEMPTS): " ANSWER

            case "${ANSWER,,}" in
                hint)
                    echo -e "\n\033[1;33mHint:\033[0m $HINT"
                    continue
                    ;;
                health)
                    display_health "$HEALTH"
                    continue
                    ;;
                score)
                    echo -e "📊 \033[1;33mCurrent Score:\033[0m $(get_score $user_id $role)"
                    continue
                    ;;
                skip)
                    echo -e "\n⏩ \033[1;33mSkipping this riddle...\033[0m"
                    ((HEALTH--))
                    update_health $user_id "$HEALTH"
                    mysql_query "INSERT INTO user_progress (user_id, riddle_id, riddle_source, is_solved, score, role)
                                 VALUES ($user_id, $RID, '$role', FALSE, 0, '$role')
                                 ON DUPLICATE KEY UPDATE is_solved = FALSE, score = 0;"
                    break
                    ;;
                exit|quit)
                    echo "Thanks for playing! Your progress has been saved."
                    update_health $user_id "$HEALTH"
                    exit 0
                    ;;
                *)
                    ((ATTEMPTS++))

                    if [[ "${ANSWER,,}" == "${CORRECT_ANSWER,,}" ]]; then
                        echo -e "\n✅ \033[1;32mCorrect!\033[0m"
                        mysql_query "INSERT INTO user_progress (user_id, riddle_id, riddle_source, is_solved, score, role)
                                     VALUES ($user_id, $RID, '$role', TRUE, $SCORE_VALUE, '$role')
                                     ON DUPLICATE KEY UPDATE is_solved = TRUE, score = $SCORE_VALUE;"
                        echo -e "⭐ \033[1;33m+$SCORE_VALUE points!\033[0m"
                        SCORE=$(get_score $user_id $role)
                        echo -e "📊 \033[1;33mTotal Score:\033[0m $SCORE"
                        break
                    else
                        ((HEALTH--))
                        update_health $user_id "$HEALTH"

                        if (( ATTEMPTS < MAX_ATTEMPTS )); then
                            echo -e "\n❌ \033[1;31mIncorrect! Health decreased.\033[0m"
                            display_health "$HEALTH"
                        else
                            echo -e "\n🛑 \033[1;31mMaximum attempts reached!\033[0m"
                            echo -e "The correct answer was: \033[1;33m$CORRECT_ANSWER\033[0m"
                            mysql_query "INSERT INTO user_progress (user_id, riddle_id, riddle_source, is_solved, score, role)
                                         VALUES ($user_id, $RID, '$role', FALSE, 0, '$role')
                                         ON DUPLICATE KEY UPDATE is_solved = FALSE, score = 0;"
                        fi
                    fi
                    ;;
            esac
        done

        if (( HEALTH <= 0 )); then
            echo -e "\n💀 \033[1;31mGAME OVER! You've run out of health.\033[0m"
            echo -e "🏆 \033[1;33mFinal Score:\033[0m $(get_score $user_id $role)"
            break
        fi
    done

    FINAL_SCORE=$(get_score $user_id $role)
    mysql_query "INSERT INTO applications (user_id, role, riddle_score, status)
                 VALUES ($user_id, '$role', $FINAL_SCORE, 'pending')
                 ON DUPLICATE KEY UPDATE riddle_score = $FINAL_SCORE, status = 'pending';"
    
    echo -e "\n🎉 \033[1;32mScreening completed!\033[0m"
    echo -e "🏆 \033[1;33mFinal Score:\033[0m $FINAL_SCORE"
    echo -e "❤ Remaining health: $HEALTH/5"
    read -p "Press Enter to return to dashboard..."
}

show_menu "$username" "$USER_ID" "$2" "$3"