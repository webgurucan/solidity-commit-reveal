# Vanity name registering system resistant against frontrunning

## Features
You can register unique names through this system. It will prevent frontrunning by commit-reveal pattern.
- You commit your desired name and salt. When you commit, you should deposit some amount which you can withdraw when you cancel registration.
- After certain amount of time (32 blocks later), you can reveal your desired name with salt. In case you can register the name, then you have to pay for registration.
In case it is duplicated, then all funds (deposit and the reveal payment) will be returned to you.
- If you want to cancel registration before reveal, you have to wait for certain amount of time and withdraw the deposit.


