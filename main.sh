#!/bin/bash

# Function to check if username exists
username_exists() {
    local username=$1
    # Check in database (MySQL)
    count=$(mysql -N -s -e "SELECT COUNT(*) FROM recruitment_portal2.users WHERE username='$username';")
    # Also check local user directory for consistency
    if [ -d "users/$username" ] || [ "$count" -gt 0 ]; then
        return 0 # exists
    else
        return 1 # available
    fi
}

# Main menu
while true; do
    clear
    echo "Welcome to Recruitment Portal"
    echo "1. Register"
    echo "2. Login"
    echo "3. Admin Login"
    echo "4. Exit"
    read -p "Choose option: " choice

    case $choice in
        1)
            while true; do
                read -p "Username: " username
                if username_exists "$username"; then
                    echo "Username already exists! Please choose another."
                else
                    break
                fi
            done
            
            read -s -p "Password: " password
            echo
            read -p "Email: " email
            
            # Create user directory and database record
            mkdir -p "users/$username"
            echo "{\"username\":\"$username\",\"password\":\"$password\",\"email\":\"$email\"}" > "users/$username/profile.json"
            
            # Add to database
            mysql -e "INSERT INTO recruitment_portal2.users (username, password_hash, email) 
                     VALUES ('$username', '$password', '$email');"
            
            echo "Account created for user $username! Please login."
            sleep 2
            ;;
        2)
            read -p "Username: " username
            read -s -p "Password: " password
            echo
            
            # Verify credentials against database
            valid=$(mysql -N -s -e "SELECT COUNT(*) FROM recruitment_portal2.users 
                                  WHERE username='$username' AND password_hash='$password';")
            
            if [ "$valid" -eq 1 ]; then
                ./user_dashboard.sh "$username"
            else
                echo "Invalid credentials"
            fi
            ;;
        3)
            # Admin login with credentials check
            read -p "Admin Username: " admin_user
            read -s -p "Admin Password: " admin_pass
            echo
            
            # Verify admin credentials
            is_admin=$(mysql -N -s -e "SELECT COUNT(*) FROM recruitment_portal2.users 
                                     WHERE username='$admin_user' AND password_hash='$admin_pass' 
                                     AND role='admin';")
            
            if [ "$is_admin" -eq 1 ]; then
                clear
                echo "Welcome Admin!"
                ./admin/admin_console.sh
            else
                echo "Invalid admin credentials"
            fi
            ;;
        4)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done
