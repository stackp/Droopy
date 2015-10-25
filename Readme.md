# Droopy
### Easy File Sharing
Copyright 2008-2013 (c) Pierre Duquesne <stackp@online.fr>
Licensed under the New BSD License.
Originally shared at [Pierre's Blog, stackp.online.fr](http://stackp.online.fr/droopy).

### About
Droopy is a standalone, minimal file-sharing server written in pure Python and
designed for simplicity. Originally written to facilitate easy sharing on an
ad-hoc basis, it has become central to systems such as [Piratebox](http://www.piratebox.cc/)
which extend the concept to offline, social filesharing.

![Droopy in the Browser, with a title image](img/droopy-in-browser-thumb.png)

### Usage
Note: [A tutorial on how to set up Droopy on Windows](http://www.techkings.org/general-pc-chat/34104-droopy-tutorial.html)
was very kindly written by Ronan. The rest of this section focuses on Linux and MacOSX.

Droopy is a command-line program. I’ll suppose you’ve downloaded and saved the file in `~/bin/`.
Go to the directory where you want the uploaded files to be stored, for example:

    mkdir ~/uploads
    cd ~/uploads 

Then, run droopy. You can give a message and a picture to display:

    python3 ~/bin/droopy -m "Hi, it's me Bob. You can send me a file." -p ~/avatar.png

![Droopy at the terminal](img/droopy-in-terminal-thumb.png)

And it’s up and running on port 8000 of you computer. Check it out at `http://localhost:8000`,
and give your computer’s address to your friends.

Droopy supports a number of other options; try `python3 droopy --help` for insight.
On Linux, droopy can be run directly without specifically calling `python3`, so
you can put `droopy` into a folder that's in your system PATH variable, such as
`/usr/bin/` and call it directly: `droopy --help`.

### Feedback and contribution
I’d love to hear about your experience using droopy.
If you have ideas to improve it, please let me know.
Pierre – [stackp@online.fr](mailto:stackp@online.fr). 
