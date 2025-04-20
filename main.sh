#!/bin/bash

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "Error: whiptail is not installed. Please install it to use the enhanced UI."
    exit 1
fi

# Function to check if username exists using whiptail
username_exists() {
    local username=$1
    echo "DEBUG: username_exists called with username: '$username'" # Add this line
    local count=$(mysql -N -s -e "SELECT COUNT(*) FROM recruitment_portal2.users WHERE username='$username';")
    if [ -d "users/$username" ] || [ "$count" -gt 0 ]; then
        return 0 # exists
    else
        return 1 # available
    fi
}

# Main menu using whiptail
while true; do
    options=(
        "1" "Register"
        "2" "Login"
        "3" "Admin Login"
        "4" "Exit"
    )
    choice=$(whiptail --menu "Welcome to Recruitment Portal" 15 60 4 "${options[@]}" --ok-button "Select" --cancel-button "Quit" 3>&1 1>&2 2>&3)
    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        case "$choice" in
            "1")
                 while true; do
                    username=$(whiptail --inputbox "Enter Username:" 8 50 --title "Register" 3>&1 1>&2 2>&3)
                   # local username_exit_status=$?
                    #echo "DEBUG: username_exit_status after username input: $username_exit_status" # Add this line
                    #if [ $username_exit_status -ne 0 ]; then
                        #echo "DEBUG: Cancel button pressed for username" # Add this line
                    #    break # User cancelled username input, go back to main menu
                    #fi


                    # Check if username is empty (due to pressing Ok without entering text)
                    if [ -z "$username" ]; then
                        whiptail --msgbox "Username cannot be empty." 8 50 --title "Register"
                        continue # Go back to the username prompt
                    fi

                    if username_exists "$username"; then
                        whiptail --msgbox "Username already exists! Please choose another." 8 50 --title "Register"
                    else
                        password=$(whiptail --passwordbox "Enter Password:" 8 50 --title "Register" 3>&1 1>&2 2>&3)
                        # local password_exit_status=$?
                        # if [ $password_exit_status -ne 0 ]; then
                        #     break # User cancelled password input, go back to main menu
                        # fi
                        email=$(whiptail --inputbox "Enter Email:" 8 50 --title "Register" 3>&1 1>&2 2>&3)
                        # local email_exit_status=$?
                        # if [ $email_exit_status -ne 0 ]; then
                        #     break # User cancelled email input, go back to main menu
                        # fi

                        mkdir -p "users/$username"
                        echo "{\"username\":\"$username\",\"password\":\"$password\",\"email\":\"$email\"}" > "users/$username/profile.json"

                        mysql -e "INSERT INTO recruitment_portal2.users (username, password_hash, email)
                                    VALUES ('$username', '$password', '$email');"

                        whiptail --msgbox "Account created for user $username! Please login." 8 50 --title "Register"
                        sleep 1
                        break # Registration successful, go back to main menu
                    fi
                done
                ;;
            "2")
                username=$(whiptail --inputbox "Enter Username:" 8 50 --title "Login" 3>&1 1>&2 2>&3)
                # local username_exit_status=$?
                # if [ $username_exit_status -ne 0 ]; then
                #     continue # User cancelled
                # fi
                password=$(whiptail --passwordbox "Enter Password:" 8 50 --title "Login" 3>&1 1>&2 2>&3)
                # local password_exit_status=$?
                # if [ $password_exit_status -ne 0 ]; then
                #     continue # User cancelled
                # fi

                valid=$(mysql -N -s -e "SELECT COUNT(*) FROM recruitment_portal2.users
                                        WHERE username='$username' AND password_hash='$password';")

                if [ "$valid" -eq 1 ]; then
                    ./user_dashboard.sh "$username"
                    break # Exit the main menu after successful login
                else
                    whiptail --msgbox "Invalid credentials" 8 50 --title "Login"
                fi
                ;;
            "3")
                admin_user=$(whiptail --inputbox "Enter Admin Username:" 8 50 --title "Admin Login" 3>&1 1>&2 2>&3)
                local admin_user_exit_status=$?
                if [ $admin_user_exit_status -ne 0 ]; then
                    continue # User cancelled
                fi
                admin_pass=$(whiptail --passwordbox "Enter Admin Password:" 8 50 --title "Admin Login" 3>&1 1>&2 2>&3)
                local admin_pass_exit_status=$?
                if [ $admin_pass_exit_status -ne 0 ]; then
                    continue # User cancelled
                fi

                is_admin=$(mysql -N -s -e "SELECT COUNT(*) FROM recruitment_portal2.users
                                            WHERE username='$admin_user' AND password_hash='$admin_pass'
                                            AND role='admin';")

                if [ "$is_admin" -eq 1 ]; then
                    clear
                    echo "Welcome Admin!"
                    ./admin/admin_console.sh
                    break # Exit the main menu after successful admin login
                else
                    whiptail --msgbox "Invalid admin credentials" 8 50 --title "Admin Login"
                fi
                ;;
            "4")
                whiptail --msgbox "Goodbye!" 8 50
                exit 0
                ;;
        esac
    elif [ $exit_status -eq 1 ]; then
        # User pressed Cancel on the main menu
        whiptail --msgbox "Exiting Recruitment Portal." 8 50
        exit 0
    fi
done