review_candidate() {
    GREEN='\e[32m'
    RESET='\e[0m'

    while true; do
        read -p "Enter username to review (or 'back' to return): " username

        if [ "$username" == "back" ]; then
            return
        fi

        # Check if user exists
        exists=$(mysql -N -e "SELECT COUNT(*) FROM recruitment_portal2.users WHERE username='$username';")

        if [ "$exists" -eq 0 ]; then
            echo "User not found. Please try again."
            continue
        fi

        # Fetch user details
        echo
        echo -e "Candidate: ${GREEN}$username${RESET}"

        # Fetch latest resume info
        details=$(mysql -N -e "
            SELECT download_link, file_path
            FROM recruitment_portal2.user_resumes r
            JOIN recruitment_portal2.users u ON r.user_id = u.user_id
            WHERE u.username='$username'
            ORDER BY uploaded_at DESC
            LIMIT 1;")

        IFS=$'\t' read -r download_link file_path <<< "$details"

        echo -e "\nOptions:"
        echo "1. View Resume"
        echo "2. View Riddle Score"
        echo "3. Approve/Reject Application"
        echo "4. Back to menu"
        read -p "Choose action: " resume_action

        case $resume_action in
            1)
                if [ -n "$download_link" ]; then
                    echo -e "\nResume Link: $download_link"
                    echo "Local Path: $file_path"
                    if [ -f "$file_path" ]; then
                        if command -v pdftotext >/dev/null; then
                            pdftotext "$file_path" - | less
                        else
                            echo "pdftotext not available. Resume saved at: $file_path"
                        fi
                    else
                        echo "Resume file not found locally. Use the Google Drive link above."
                    fi
                else
                    echo "No resume uploaded yet."
                fi
                ;;
            2)
                echo
                echo "Fetching riddle score..."
                # Fetch the latest riddle score
                echo -e $(mysql -N -e "select riddle_score from recruitment_portal2.applications 
                        where user_id=(select user_id from recruitment_portal2.users where username='$username') 
                        order by updated_at desc limit 1;")
                ;;
            3)
                echo -e "\n==========================\n"
                echo -e "Application Actions:"
                echo "1. Approve"
                echo "2. Reject"
                echo "3. Back to menu"
                read -p "Choose action: " action

                case $action in
                    1)
                        mysql -e "
                            UPDATE recruitment_portal2.applications 
                            SET status='approved' 
                            WHERE user_id=(SELECT user_id FROM recruitment_portal2.users WHERE username='$username');"
                        echo "User approved!"
                        ;;
                    2)
                        mysql -e "
                            UPDATE recruitment_portal2.applications 
                            SET status='rejected' 
                            WHERE user_id=(SELECT user_id FROM recruitment_portal2.users WHERE username='$username');"
                        echo "User rejected."
                        ;;
                    3)
                        break
                        ;;
                    *)
                        echo "Invalid option"
                        ;;
                esac
                ;;
            
            4)
                continue
                ;;
            *)
                echo "Invalid option"
                ;;
        esac

        # Check if an application already exists
        application_exists=$(mysql -N -e "
            SELECT COUNT(*) FROM recruitment_portal2.applications 
            WHERE user_id = (SELECT user_id FROM recruitment_portal2.users WHERE username = '$username');")

        if [ "$application_exists" -eq 0 ]; then
            mysql -e "
                INSERT INTO recruitment_portal2.applications (user_id)
                VALUES ((SELECT user_id FROM recruitment_portal2.users WHERE username = '$username'));"
        fi

        read -p "Review another candidate? (y/n): " another
        if [ "$another" != "y" ]; then
            echo "Logging out..."
            sleep 1
            break
        fi
    done
}

review_candidate