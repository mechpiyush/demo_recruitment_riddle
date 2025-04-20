#!/bin/bash
username=$1

upload_resume() {
    echo "Please upload your resume as a Google Drive shareable link"
    echo "Instructions:"
    echo "1. Upload your resume to Google Drive"
    echo "2. Right-click on the file and select 'Share'"
    echo "3. Set sharing to 'Anyone with the link'"
    echo "4. Copy the link and paste it below"

    while true; do
        read -p "Google Drive link: " drive_link

        # Remove URL parameters and fragments
        clean_link=$(echo "$drive_link" | sed 's/[?#].*$//')

        # Extract file ID from multiple link formats
        file_id=$(echo "$clean_link" | sed -n -E \
        -e 's|^https://drive.google.com/file/d/([^/]+)/?.*|\1|p' \
        -e 's|^https://drive.google.com/open\?id=([^&]+).*|\1|p' \
        -e 's|^https://docs.google.com/document/d/([^/]+)/?.*|\1|p')

        if [ -z "$file_id" ]; then
            echo "Invalid Google Drive link format. Please provide a valid shareable link."
            echo "Accepted formats:"
            echo "1. https://drive.google.com/file/d/FILE_ID/view"
            echo "2. https://drive.google.com/open?id=FILE_ID"
            echo "3. https://docs.google.com/document/d/FILE_ID/edit"
            continue
        fi

        # Create user's document directory if it doesn't exist
        mkdir -p "users/$username/documents"

        # Download the file using curl
        echo "Downloading resume..."
        download_url="https://drive.google.com/uc?export=download&id=$file_id"

        if curl -L -g "$download_url" -o "users/$username/documents/resume.pdf"; then
            # Optional: Check for HTML page instead of actual PDF
            if grep -q "<html" "users/$username/documents/resume.pdf"; then
                echo "Download failed – the file might not be publicly accessible or is too large."
                rm "users/$username/documents/resume.pdf"
                continue
            fi

            # Store in database
            mysql -e "INSERT INTO recruitment_portal2.user_resumes (user_id, file_path, file_name, download_link)
                     VALUES ((SELECT user_id FROM recruitment_portal2.users WHERE username='$username'), 
                     'users/$username/documents/resume.pdf', 'resume.pdf', '$drive_link')
                     ON DUPLICATE KEY UPDATE file_path='users/$username/documents/resume.pdf', 
                     file_name='resume.pdf', download_link='$drive_link';"

            echo "Resume successfully downloaded!"
            break
        else
            echo "Failed to download resume. Please check:"
            echo "1. The link is set to 'Anyone with the link can view'"
            echo "2. The file is not too large (Google has download limits)"
            echo "3. You have stable internet connection"
        fi
    done
}

while true; do
    clear
    echo "Welcome $username!"
    echo "1. View Openings"
    echo "2. Upload Resume"
    echo "3. Exit"
    echo "-----------------------------------"
    read -p "Choose option: " choice
    echo "-----------------------------------"

    case $choice in
        1)
            # Display available roles
            echo
            echo "Available Roles:"
            echo "1. Software Engineer"
            echo "2. Data Scientist"
            echo "3. DevOps Engineer"
            echo "-----------------------------------" 
            read -p "Select role to begin screening (or 'back' to return): " role
            echo "-----------------------------------" 
            
            case $role in
                1) ./games/riddles.sh "$username" "software_engineer" "Software Engineer" ;;
                2) ./games/riddles.sh "$username" "data_scientist" "Data Scientist";;
                3) ./games/riddles.sh "$username" "devops" "DevOps";;
                back) continue ;;
                *) echo "Invalid role" ;;
            esac
            sleep 2
            ;;
        2)
            upload_resume
            read -p "Press Enter to continue..."
            ;;
        3)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done