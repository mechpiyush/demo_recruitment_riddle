-- Create the database
DROP DATABASE IF EXISTS recruitment_portal2;
CREATE DATABASE recruitment_portal2;
USE recruitment_portal2;

-- Create users table
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role VARCHAR(20) DEFAULT 'candidate',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    INDEX idx_username (username)
);

-- Create software_engineer_riddles table
CREATE TABLE software_engineer_riddles (
    riddle_id INT AUTO_INCREMENT PRIMARY KEY,
    riddle_text TEXT NOT NULL,
    hint TEXT,
    correct_answer VARCHAR(255) NOT NULL,
    difficulty VARCHAR(20) DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    score_value INT DEFAULT 10
);

-- Create devops_riddles table
CREATE TABLE devops_riddles (
    riddle_id INT AUTO_INCREMENT PRIMARY KEY,
    riddle_text TEXT NOT NULL,
    hint TEXT,
    correct_answer VARCHAR(255) NOT NULL,
    difficulty VARCHAR(20) DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    score_value INT DEFAULT 10
);

-- Create data_scientist_riddles table
CREATE TABLE data_scientist_riddles (
    riddle_id INT AUTO_INCREMENT PRIMARY KEY,
    riddle_text TEXT NOT NULL,
    hint TEXT,
    correct_answer VARCHAR(255) NOT NULL,
    difficulty VARCHAR(20) DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    score_value INT DEFAULT 10
);

-- Create user_stats table
CREATE TABLE user_stats (
    stats_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    current_score INT DEFAULT 0,
    current_health INT DEFAULT 5,
    max_health INT DEFAULT 5,
    total_riddles_solved INT DEFAULT 0,
    software_engineer_score INT DEFAULT 0,
    data_scientist_score INT DEFAULT 0,
    devops_score INT DEFAULT 0,
    current_role VARCHAR(50),
    last_played TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    INDEX idx_user_id (user_id)
);

-- Create user_resumes table
CREATE TABLE user_resumes (
    resume_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    file_path VARCHAR(255) NOT NULL,
    file_name VARCHAR(100) NOT NULL,
    download_link VARCHAR(255),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Create applications table
CREATE TABLE applications (
    application_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    role VARCHAR(50) NOT NULL,
    riddle_score INT DEFAULT 0,
    resume_score INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending',
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    INDEX idx_user_role (user_id, role)
);

-- Create user_progress table
CREATE TABLE user_progress (
    progress_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    riddle_id INT NOT NULL,
    riddle_source VARCHAR(50) NOT NULL,
    role VARCHAR(50) NOT NULL,
    is_solved BOOLEAN DEFAULT FALSE,
    score INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending',
    attempts INT DEFAULT 0,
    solved_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    INDEX idx_user_role_riddle (user_id, role, riddle_id),
    INDEX idx_user_source (user_id, riddle_source)
);

-- Create indexes for better performance
CREATE INDEX idx_user_progress_user_role ON user_progress(user_id, role);
CREATE INDEX idx_user_stats_user ON user_stats(user_id);

-- Insert sample data (optional)
-- Insert sample users
INSERT INTO users (username, password_hash, email, role) VALUES
('admin', '$2a$10$xJwL5v5Jz5UJz5UJz5UJzOe5UJz5UJz5UJz5UJz5UJz5UJz5UJz5U', 'admin@example.com', 'admin'),
('candidate1', '$2a$10$xJwL5v5Jz5UJz5UJz5UJzOe5UJz5UJz5UJz5UJz5UJz5UJz5UJz5U', 'candidate1@example.com', 'candidate'),
('candidate2', '$2a$10$xJwL5v5Jz5UJz5UJz5UJzOe5UJz5UJz5UJz5UJz5UJz5UJz5UJz5U', 'candidate2@example.com', 'candidate');

-- Insert sample riddles for software engineer
INSERT INTO software_engineer_riddles (riddle_text, hint, correct_answer, difficulty, score_value) VALUES
('What has keys but can''t open locks?', 'Think about input devices', 'keyboard', 'easy', 5),
('I speak without a mouth and hear without ears. I have no body, but I come alive with wind. What am I?', 'Think about sound reproduction', 'echo', 'medium', 10),
('The more you take, the more you leave behind. What am I?', 'Think about walking', 'footsteps', 'hard', 15);

-- Insert sample riddles for devops
INSERT INTO devops_riddles (riddle_text, hint, correct_answer, difficulty, score_value) VALUES
('I can be created but not destroyed. I can be stopped but not paused. What am I?', 'Think about server processes', 'process', 'easy', 5),
('What gets bigger the more you remove from it?', 'Think about storage', 'hole', 'medium', 10),
('I have cities but no houses, forests but no trees, and water but no fish. What am I?', 'Think about representations', 'map', 'hard', 15);

-- Insert sample riddles for data scientist
INSERT INTO data_scientist_riddles (riddle_text, hint, correct_answer, difficulty, score_value) VALUES
('What has a head, a tail, but no body?', 'Think about probability', 'coin', 'easy', 5),
('I''m tall when I''m young and short when I''m old. What am I?', 'Think about time measurement', 'candle', 'medium', 10),
('What can you catch but not throw?', 'Think about health', 'cold', 'hard', 15);

-- Insert sample user stats
INSERT INTO user_stats (user_id, current_score, current_health, max_health) VALUES
(2, 0, 5, 5),
(3, 0, 5, 5);