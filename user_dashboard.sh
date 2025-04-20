#!/bin/bash

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "Error: whiptail is not installed. Please install it to use the enhanced UI."
    exit 1
fi

username=$1

upload_resume() {
    whiptail --title "Upload Resume" --msgbox "Please upload your resume as a Google Drive shareable link.

Instructions:
1. Upload your resume to Google Drive.
2. Right-click on the file and select 'Share'.
3. Set sharing to 'Anyone with the link'.
4. Copy the link and paste it in the input box." 15 60 --ok-button "Continue" --cancel-button "Back" 3>&1 1>&2 2>&3

    local upload_status=$?
    if [ $upload_status -eq 1 ]; then
        return 1 # User cancelled
    fi

    while true; do
        drive_link=$(whiptail --inputbox "Google Drive Link:" 8 60 --title "Upload Resume" 3>&1 1>&2 2>&3)
        local link_status=$?

        if [ $link_status -ne 0 ]; then
            return 1 # User cancelled
        fi

        # Remove URL parameters and fragments
        clean_link=$(echo "$drive_link" | sed 's/[?#].*$//')

        # Extract file ID from multiple link formats
        file_id=$(echo "$clean_link" | sed -n -E \
            -e 's|^https://drive.google.com/file/d/([^/]+)/?.*|\1|p' \
            -e 's|^https://drive.google.com/open\?id=([^&]+).*|\1|p' \
            -e 's|^https://docs.google.com/document/d/([^/]+)/?.*|\1|p')

        if [ -z "$file_id" ]; then
            whiptail --msgbox "Invalid Google Drive link format. Accepted formats:\n\n1. https://drive.google.com/file/d/FILE_ID/view\n2. https://drive.google.com/open?id=FILE_ID\n3. https://docs.google.com/document/d/FILE_ID/edit" 12 60 --title "Upload Resume"
            continue
        fi

        # Create user's document directory if it doesn't exist
        mkdir -p "users/$username/documents"

        # Download the file using curl
        whiptail --title "Uploading" --infobox "Downloading resume..." 5 30
        download_url="https://drive.google.com/uc?export=download&id=$file_id"

        if curl -L -g "$download_url" -o "users/$username/documents/resume.pdf"; then
            # Optional: Check for HTML page instead of actual PDF
            if grep -q "<html" "users/$username/documents/resume.pdf"; then
                whiptail --msgbox "Download failed – the file might not be publicly accessible or is too large." 8 60 --title "Error"
                rm "users/$username/documents/resume.pdf"
                continue
            fi

            # Store in database
            mysql -e "INSERT INTO recruitment_portal2.user_resumes (user_id, file_path, file_name, download_link)
                        VALUES ((SELECT user_id FROM recruitment_portal2.users WHERE username='$username'),
                        'users/$username/documents/resume.pdf', 'resume.pdf', '$drive_link')
                        ON DUPLICATE KEY UPDATE file_path='users/$username/documents/resume.pdf',
                        file_name='resume.pdf', download_link='$drive_link';"

            whiptail --msgbox "Resume successfully downloaded!" 8 40 --title "Success"
            break
        else
            whiptail --msgbox "Failed to download resume. Please check:\n\n1. The link is set to 'Anyone with the link can view'\n2. The file is not too large (Google has download limits)\n3. You have stable internet connection" 12 60 --title "Error"
        fi
    done
}

while true; do
    options=(
        "1" "View Openings"
        "2" "Upload Resume"
        "3" "Exit"
    )
    choice=$(whiptail --menu "Welcome $username!" 10 60 3 "${options[@]}" --ok-button "Select" --cancel-button "Exit" 3>&1 1>&2 2>&3)
    menu_status=$?

    if [ $menu_status -eq 0 ]; then
        case "$choice" in
            "1")
                role_options=(
                    "1" "Software Engineer"
                    "2" "Data Scientist"
                    "3" "DevOps Engineer"
                    "back" "Back to Main Menu"
                )
                selected_role=$(whiptail --menu "Available Roles:" 12 60 4 "${role_options[@]}" --ok-button "Select" --cancel-button "Back" 3>&1 1>&2 2>&3)
                role_status=$?

                if [ $role_status -eq 0 ]; then
                    case "$selected_role" in
                        "1") ./games/riddles.sh "$username" "software_engineer" "Software Engineer" ;;
                        "2") ./games/riddles.sh "$username" "data_scientist" "Data Scientist" ;;
                        "3") ./games/riddles.sh "$username" "devops" "DevOps" ;;
                        "back") continue ;;
                        *) whiptail --msgbox "Invalid role selected." 8 40 --title "Error" ;;
                    esac
                    sleep 2
                fi
                ;;
            "2")
                if upload_resume; then
                    whiptail --msgbox "Press Enter to continue..." 6 40
                    read
                fi
                ;;
            "3")
                whiptail --msgbox "Goodbye!" 6 40
                exit 0
                ;;
        esac
    elif [ $menu_status -eq 1 ]; then
        whiptail --msgbox "Exiting." 6 40
        exit 0
    fi
done