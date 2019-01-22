def sign_in(user)
    visit new_session_path
    fill_in 'Username' , with: user.username
    fill_in 'Password' , with: user.password
    click_button 'Login' 
end

def admin_sign_in(user)
    visit admin_new_session_path
    fill_in 'Username' , with: user.username
    fill_in 'Password' , with: user.password
    click_button 'Login' 
end

def in_browser(name)
  old_session = Capybara.session_name

  Capybara.session_name = name
  yield

  Capybara.session_name = old_session
end
