#!/usr/bin/env python
# -*- coding: utf-8 -*- 

# Droopy (http://stackp.online.fr/droopy)
# Copyright 2008 (C) Pierre Duquesne <stackp@online.fr>
# Licensed under the Python Software Foundation License
# (http://www.python.org/psf/license/)

# Changelog
#   20091229 * Brazilian Portuguese translation by
#              Carlos Eduardo Moreira dos Santos and Toony Poony.
#            * IE layout fix by Carlos Eduardo Moreira dos Santos.
#            * Galician translation by Miguel Anxo Bouzada.
#   20090721 * Indonesian translation by Kemas.
#   20090205 * Japanese translation by Satoru Matsumoto.
#            * Slovak translation by CyberBoBaK.
#   20090203 * Norwegian translation by Preben Olav Pedersen.
#   20090202 * Korean translation by xissy.
#            * Fix for unicode filenames by xissy.
#            * Relies on 127.0.0.1 instead of "localhost" hostname.
#   20090129 * Serbian translation by kotnik.
#   20090125 * Danish translation by jan.
#   20081210 * Greek translation by n2j3.
#   20081128 * Slovene translation by david.
#            * Romanian translation by Licaon.
#   20081022 * Swedish translation by David Eurenius.
#   20081001 * Droopy gets pretty (css and html rework).
#            * Finnish translation by ipppe.
#   20080926 * Configuration saving and loading.
#   20080906 * Extract the file base name (some browsers send the full path).
#   20080905 * File is uploaded directly into the specified directory.
#   20080904 * Arabic translation by Djalel Chefrour.
#            * Italian translation by fabius and d1s4st3r.
#            * Dutch translation by Tonio Voerman.
#            * Portuguese translation by Pedro Palma.
#            * Turkish translation by Heartsmagic.
#   20080727 * Spanish translation by Federico Kereki.
#   20080624 * Option -d or --directory to specify the upload directory.
#   20080622 * File numbering to avoid overwriting.
#   20080620 * Czech translation by Jiří.
#            * German translation by Michael.
#   20080408 * First release.

import BaseHTTPServer
import SocketServer
import cgi
import os
import posixpath
import macpath
import ntpath
import sys
import getopt
import mimetypes
import copy
import shutil
import tempfile
import socket
import locale

USAGE='''\
Usage: droopy [options] [PORT]

Options:
  -h, --help                            show this help message and exit
  -m MESSAGE, --message MESSAGE         set the message
  -p PICTURE, --picture PICTURE         set the picture
  -d DIRECTORY, --directory DIRECTORY   set the directory to upload files to
  --save-config                         save options in a configuration file
  --delete-config                       delete the configuration file and exit
  
Example:
   droopy -m "Hi, this is Bob. You can send me a file." -p avatar.png
''' 

picture = None
message = ""
port = 8000
directory = os.curdir
must_save_options = False

# -- HTML templates

style = '''<style type="text/css">
<!--
body {margin: 0; border: 0; padding: 0px; background-color: #fafafa;
      text-align: center; font-size: 0.9em; font-family: sans-serif;
      padding-top: 20px;}
#wrap {width: 500px; padding: 0px; margin: auto;
       border: 1px dashed #ccc; background-color: white;}
#wrapform {height: 75px; padding: 50px 20px 0px 20px; text-align: center;
           margin: 0; border: 0; border-bottom: 1px dashed #ccc;}
#form {}
#sending {display: none;}
#progress {display: inline;  border-collapse: separate; empty-cells: show;
           border-spacing: 6px 0; padding: 0; vertical-align: bottom;}
#progress td {height: 15px; width: 13px; background-color: #eee; 
              border: 1px solid #666; padding: 0px;}
#userinfo {border-collapse: collapse; padding:0px}
#userinfo td {border-collapse: collapse; cell-spacing: 0px; vertical-align:top}
#picture {margin: 0; padding: 20px; border: 0;}
#message {margin: 0; padding: 20px; font-family: monospace; font-size: 1.2em;
          width: 100%%;}
#linkurl {font-size: 0.8em; text-align: center; padding: 5px; float: right;
          background-color: orange; margin-top: 13px; width: 100%%;}
#linkurl a {color: white; font-weight: bold; text-decoration: none;}
#linkurl a:hover {text-decoration: underline;}
--></style>'''

userinfo = '''
  <table id="userinfo"><tr>
    <td>%(htmlpicture)s</td>
    <td id="message"> %(message)s </td>
  </tr></table>
  '''

maintmpl = '''<html><head><title>%(maintitle)s</title>
''' + style + '''
<script language="JavaScript">
function swap() {
   document.getElementById("form").style.display = "none";
   document.getElementById("sending").style.display = "block";
   update();
}
ncell = 4;
curcell = 0;
function update() {
   setTimeout(update, 300);
   e = document.getElementById("cell"+curcell);
   e.style.backgroundColor = "#eee";
   curcell = (curcell+1) %% ncell
   e = document.getElementById("cell"+curcell);
   e.style.backgroundColor = "#aaa";
}
function onunload() {
   document.getElementById("form").style.display = "block";
   document.getElementById("sending").style.display = "none";	  
}
</script></head><body>
%(linkurl)s
<div id="wrap">
  <div id="wrapform">
    <div id="form">
      <form method="post" enctype="multipart/form-data" action="">
        <input name="upfile" type="file">
        <input value="%(submit)s" onclick="swap()" type="submit">
      </form>
    </div>
    <div id="sending"> %(sending)s &nbsp;
      <table id="progress"><tr>
        <td id="cell0"/><td id="cell1"/><td id="cell2"/><td id="cell3"/>
      </tr></table>
    </div>
  </div>
''' + userinfo + '''
</div></body></html>
'''

successtmpl = '''
<html>
<head><title> %(successtitle)s </title>
''' + style + '''
</head>
<body>
<div id="wrap">
  <div id="wrapform">
    %(received)s
    <a href="/"> %(another)s </a>
  </div>
''' + userinfo + '''
</div>
</body>
</html>
'''

errortmpl = '''
<html>
<head><title> %(errortitle)s </title>
''' + style + '''
</head>
<body>
  <div id="wrap">
    <div id="wrapform">
      %(problem)s
      <a href="/"> %(retry)s </a>
    </div>
''' + userinfo + '''
</div>
</body>
</html>
''' 

linkurltmpl = '''<div id="linkurl">
<a href="http://stackp.online.fr/droopy-ip.php?port=%(port)d"> %(discover)s
</a></div>'''


templates = {"main": maintmpl, "success": successtmpl, "error": errortmpl}

# -- Translations

ar = {"maintitle":       u"إرسال ملف",
      "submit":          u"إرسال",
      "sending":         u"الملف قيد الإرسال",
      "successtitle":    u"تم استقبال الملف",
      "received":        u"تم استقبال الملف !",
      "another":         u"إرسال ملف آخر",
      "errortitle":      u"مشكلة",
      "problem":         u"حدثت مشكلة !",
      "retry":           u"إعادة المحاولة",
      "discover":        u"اكتشاف عنوان هذه الصفحة"}

cs = {"maintitle":       u"Poslat soubor",
      "submit":          u"Poslat",
      "sending":         u"Posílám",
      "successtitle":    u"Soubor doručen",
      "received":        u"Soubor doručen !",
      "another":         u"Poslat další soubor",
      "errortitle":      u"Chyba",
      "problem":         u"Stala se chyba !",
      "retry":           u"Zkusit znova.",
      "discover":        u"Zjistit adresu stránky"}

da = {"maintitle":       u"Send en fil",
      "submit":          u"Send",
      "sending":         u"Sender",
      "successtitle":    u"Fil modtaget",
      "received":        u"Fil modtaget!",
      "another":         u"Send en fil til.",
      "errortitle":      u"Problem",
      "problem":         u"Det er opstået en fejl!",
      "retry":           u"Forsøg igen.",
      "discover":        u"Find adressen til denne side"}

de = {"maintitle":       "Datei senden",
      "submit":          "Senden",
      "sending":         "Sendet",
      "successtitle":    "Datei empfangen",
      "received":        "Datei empfangen!",
      "another":         "Weitere Datei senden",
      "errortitle":      "Fehler",
      "problem":         "Ein Fehler ist aufgetreten!",
      "retry":           "Wiederholen",
      "discover":        "Internet-Adresse dieser Seite feststellen"}

el = {"maintitle":       u"Στείλε ένα αρχείο",
      "submit":          u"Αποστολή",
      "sending":         u"Αποστέλλεται...",
      "successtitle":    u"Επιτυχής λήψη αρχείου ",
      "received":        u"Λήψη αρχείου ολοκληρώθηκε",
      "another":         u"Στείλε άλλο ένα αρχείο",
      "errortitle":      u"Σφάλμα",
      "problem":         u"Παρουσιάστηκε σφάλμα",
      "retry":           u"Επανάληψη",
      "discover":        u"Βρες την διεύθυνση της σελίδας"}

en = {"maintitle":       "Send a file",
      "submit":          "Send",
      "sending":         "Sending",
      "successtitle":    "File received",
      "received":        "File received !",
      "another":         "Send another file.",
      "errortitle":      "Problem",
      "problem":         "There has been a problem !",
      "retry":           "Retry.",
      "discover":        "Discover the address of this page"}

es = {"maintitle":       u"Enviar un archivo",
      "submit":          u"Enviar",
      "sending":         u"Enviando",
      "successtitle":    u"Archivo recibido",
      "received":        u"¡Archivo recibido!",
      "another":         u"Enviar otro archivo.",
      "errortitle":      u"Error",
      "problem":         u"¡Hubo un problema!",
      "retry":           u"Reintentar",
      "discover":        u"Descubrir la dirección de esta página"}

fi = {"maintitle":       u"Lähetä tiedosto",
      "submit":          u"Lähetä",
      "sending":         u"Lähettää",
      "successtitle":    u"Tiedosto vastaanotettu",
      "received":        u"Tiedosto vastaanotettu!",
      "another":         u"Lähetä toinen tiedosto.",
      "errortitle":      u"Virhe",
      "problem":         u"Virhe lahetettäessä tiedostoa!",
      "retry":           u"Uudelleen.",
      "discover":        u"Näytä tämän sivun osoite"}

fr = {"maintitle":       u"Envoyer un fichier",
      "submit":          u"Envoyer",
      "sending":         u"Envoi en cours",
      "successtitle":    u"Fichier reçu",
      "received":        u"Fichier reçu !",
      "another":         u"Envoyer un autre fichier.",
      "errortitle":      u"Problème",
      "problem":         u"Il y a eu un problème !",
      "retry":           u"Réessayer.",
      "discover":        u"Découvrir l'adresse de cette page"}

gl = {"maintitle":       u"Enviar un ficheiro",
      "submit":          u"Enviar",
      "sending":         u"Enviando",
      "successtitle":    u"Ficheiro recibido",
      "received":        u"Ficheiro recibido!",
      "another":         u"Enviar outro ficheiro.",
      "errortitle":      u"Erro",
      "problem":         u"Xurdíu un problema!",
      "retry":           u"Reintentar",
      "discover":        u"Descubrir o enderezo desta páxina"}

id = {"maintitle":       "Kirim sebuah berkas",
      "submit":          "Kirim",
      "sending":         "Mengirim",
      "successtitle":    "Berkas diterima",
      "received":        "Berkas diterima!",
      "another":         "Kirim berkas yang lain.",
      "errortitle":      "Permasalahan",
      "problem":         "Telah ditemukan sebuah kesalahan!",
      "retry":           "Coba kembali.",
      "discover":        "Kenali alamat IP dari halaman ini"}

it = {"maintitle":       u"Invia un file",
      "submit":          u"Invia",
      "sending":         u"Invio in corso",
      "successtitle":    u"File ricevuto",
      "received":        u"File ricevuto!",
      "another":         u"Invia un altro file.",
      "errortitle":      u"Errore",
      "problem":         u"Si è verificato un errore!",
      "retry":           u"Riprova.",
      "discover":        u"Scopri l’indirizzo di questa pagina"}

ja = {"maintitle":       u"ファイル送信",
      "submit":          u"送信",
      "sending":         u"送信中",
      "successtitle":    u"受信完了",
      "received":        u"ファイルを受信しました！",
      "another":         u"他のファイルを送信する",
      "errortitle":      u"問題発生",
      "problem":         u"問題が発生しました！",
      "retry":           u"リトライ",
      "discover":        u"このページのアドレスを確認する"}

ko = {"maintitle":       u"파일 보내기",
      "submit":          u"보내기",
      "sending":         u"보내는 중",
      "successtitle":    u"파일이 받아졌습니다",
      "received":        u"파일이 받아졌습니다!",
      "another":         u"다른 파일 보내기",
      "errortitle":      u"문제가 발생했습니다",
      "problem":         u"문제가 발생했습니다!",
      "retry":           u"다시 시도",
      "discover":        u"이 페이지 주소 알아보기"}

nl = {"maintitle":       "Verstuur een bestand",
      "submit":          "Verstuur",
      "sending":         "Bezig met versturen",
      "successtitle":    "Bestand ontvangen",
      "received":        "Bestand ontvangen!",
      "another":         "Verstuur nog een bestand.",
      "errortitle":      "Fout",
      "problem":         "Er is een fout opgetreden!",
      "retry":           "Nog eens.",
      "discover":        "Vind het adres van deze pagina"}

no = {"maintitle":       u"Send en fil",
      "submit":          u"Send",
      "sending":         u"Sender",
      "successtitle":    u"Fil mottatt",
      "received":        u"Fil mottatt !",
      "another":         u"Send en ny fil.",
      "errortitle":      u"Feil",
      "problem":         u"Det har skjedd en feil !",
      "retry":           u"Send på nytt.",
      "discover":        u"Finn addressen til denne siden"}

pt = {"maintitle":       u"Enviar um ficheiro",
      "submit":          u"Enviar",
      "sending":         u"A enviar",
      "successtitle":    u"Ficheiro recebido",
      "received":        u"Ficheiro recebido !",
      "another":         u"Enviar outro ficheiro.",
      "errortitle":      u"Erro",
      "problem":         u"Ocorreu um erro !",
      "retry":           u"Tentar novamente.",
      "discover":        u"Descobrir o endereço desta página"}

pt_br = {
      "maintitle":       u"Enviar um arquivo",
      "submit":          u"Enviar",
      "sending":         u"Enviando",
      "successtitle":    u"Arquivo recebido",
      "received":        u"Arquivo recebido!",
      "another":         u"Enviar outro arquivo.",
      "errortitle":      u"Erro",
      "problem":         u"Ocorreu um erro!",
      "retry":           u"Tentar novamente.",
      "discover":        u"Descobrir o endereço desta página"}

ro = {"maintitle":       u"Trimite un fişier",
      "submit":          u"Trimite",
      "sending":         u"Se trimite",
      "successtitle":    u"Fişier recepţionat",
      "received":        u"Fişier recepţionat !",
      "another":         u"Trimite un alt fişier.",
      "errortitle":      u"Problemă",
      "problem":         u"A intervenit o problemă !",
      "retry":           u"Reîncearcă.",
      "discover":        u"Descoperă adresa acestei pagini"}

sk = {"maintitle":       u"Pošli súbor",
      "submit":          u"Pošli",
      "sending":         u"Posielam",
      "successtitle":    u"Súbor prijatý",
      "received":        u"Súbor prijatý !",
      "another":         u"Poslať ďalší súbor.",
      "errortitle":      u"Chyba",
      "problem":         u"Vyskytla sa chyba!",
      "retry":           u"Skúsiť znova.",
      "discover":        u"Zisti adresu tejto stránky"}

sl = {"maintitle":       u"Pošlji datoteko",
      "submit":          u"Pošlji",
      "sending":         u"Pošiljam",
      "successtitle":    u"Datoteka prejeta",
      "received":        u"Datoteka prejeta !",
      "another":         u"Pošlji novo datoteko.",
      "errortitle":      u"Napaka",
      "problem":         u"Prišlo je do napake !",
      "retry":           u"Poizkusi ponovno.",
      "discover":        u"Poišči naslov na tej strani"}

sr = {"maintitle":       u"Pošalji fajl",
      "submit":          u"Pošalji",
      "sending":         u"Šaljem",
      "successtitle":    u"Fajl primljen",
      "received":        u"Fajl primljen !",
      "another":         u"Pošalji još jedan fajl.",
      "errortitle":      u"Problem",
      "problem":         u"Desio se problem !",
      "retry":           u"Pokušaj ponovo.",
      "discover":        u"Otkrij adresu ove stranice"}

sv = {"maintitle":       u"Skicka en fil",
      "submit":          u"Skicka",
      "sending":         u"Skickar...",
      "successtitle":    u"Fil mottagen",
      "received":        u"Fil mottagen !",
      "another":         u"Skicka en fil till.",
      "errortitle":      u"Fel",
      "problem":         u"Det har uppstått ett fel !",
      "retry":           u"Försök igen.",
      "discover":        u"Ta reda på adressen till denna sida"}

tr = {"maintitle":       u"Dosya gönder",
      "submit":          u"Gönder",
      "sending":         u"Gönderiliyor...",
      "successtitle":    u"Gönderildi",
      "received":        u"Gönderildi",
      "another":         u"Başka bir dosya gönder.",
      "errortitle":      u"Problem.",
      "problem":         u"Bir problem oldu !",
      "retry":           u"Yeniden dene.",
      "discover":        u"Bu sayfanın adresini bul"}

translations = {"ar": ar, "cs": cs, "da": da, "de": de, "el": el, "en": en,
                "es": es, "fi": fi, "fr": fr, "gl": gl, "id": id, "it": it,
                "ja": ja, "ko": ko, "nl": nl, "no": no, "pt": pt,
                "pt-br": pt_br, "ro": ro, "sk": sk, "sl": sl, "sr": sr,
                "sv": sv, "tr": tr}


class DroopyFieldStorage(cgi.FieldStorage):
    """The file is created in the destination directory and its name is
    stored in the tmpfilename attribute.
    """

    def make_file(self, binary=None):
        fd, name = tempfile.mkstemp(dir=directory)
        self.tmpfile = os.fdopen(fd, 'w+b')
        self.tmpfilename = name
        return self.tmpfile


class HTTPUploadHandler(BaseHTTPServer.BaseHTTPRequestHandler):

    form_field = 'upfile'

    def html(self, page):
        """
        page can be "main", "success", or "error"
        returns an html page (in the appropriate language) as a string
        """
        
        # -- Parse accept-language header
        if not self.headers.has_key("accept-language"):
            a = []
        else:
            a = self.headers["accept-language"]
            a = a.split(',')
            a = [e.split(';q=') for e in  a]
            a = [(lambda x: len(x)==1 and (1, x[0]) or
                                           (float(x[1]), x[0])) (e) for e in a]
            a.sort()
            a.reverse()
            a = [x[1] for x in a]
        # now a is an ordered list of preferred languages
            
        # -- Choose the appropriate translation dictionary (default is english)
        lang = "en"
        for l in a:
            if translations.has_key(l):
                lang = l
                break
        dico = copy.copy(translations[lang])

        # -- Set message and picture
        dico["message"] = message
        if picture != None:
            dico["htmlpicture"] = '<div id="picture"><img src="/%s"/></div>' %\
                                                      os.path.basename(picture)
        else:
            dico["htmlpicture"] = ""

        # -- Add a link to discover the url
        if self.client_address[0] == "127.0.0.1":
            dico["port"] = self.server.server_port
            dico["linkurl"] =  linkurltmpl % dico
        else:
            dico["linkurl"] = ""

        return templates[page] % dico


    def do_GET(self):
        if picture != None and self.path == '/' + os.path.basename(picture):
            # send the picture
            self.send_response(200)                      
            self.send_header('Content-type', mimetypes.guess_type(picture)[0]) 
            self.end_headers()
            self.wfile.write(open(picture, 'rb').read())
        else:
            # send the upload form
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(self.html("main").encode('utf-8'))


    def do_POST(self):
        # Do some browsers /really/ use multipart ? maybe Opera ?
        try:
            self.log_message("Started file transfer")
            
            # -- Set up environment for cgi.FieldStorage
            env = {}
            env['REQUEST_METHOD'] = self.command
            if self.headers.typeheader is None:
                env['CONTENT_TYPE'] = self.headers.type
            else:
                env['CONTENT_TYPE'] = self.headers.typeheader

            # -- Save file (numbered to avoid overwriting, ex: foo-3.png)
            form = DroopyFieldStorage(fp = self.rfile, environ = env);
            fileitem = form[self.form_field]
            filename = self.basename(fileitem.filename).decode('utf-8')
            if filename == "":
                raise Exception("Empty filename")
            localpath = os.path.join(directory, filename).encode('utf-8')
            root, ext = os.path.splitext(localpath)
            i = 1
            # race condition, but hey...
            while (os.path.exists(localpath)): 
                localpath = "%s-%d%s" % (root, i, ext)
                i = i+1
            if hasattr(fileitem, 'tmpfile'):
                # DroopyFieldStorage.make_file() has been called
                fileitem.tmpfile.close()
                shutil.move(fileitem.tmpfilename, localpath)
            else:
                # no temporary file, self.file is a StringIO()
                # see cgi.FieldStorage.read_lines()
                fout = file(localpath, 'wb')
                shutil.copyfileobj(fileitem.file, fout)
                fout.close()
            self.log_message("Received: %s", os.path.basename(localpath))

            # -- Reply
            self.send_response(200)
            self.send_header('Content-type','text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(self.html("success").encode('utf-8'))

        except Exception, e:
            self.log_message(repr(e))
            self.send_response(200)
            self.send_header('Content-type','text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(self.html("error").encode('utf-8'))

    def basename(self, path):
        """Extract the file base name (some browsers send the full file path).
        """
        for mod in posixpath, macpath, ntpath:
            path = mod.basename(path)
        return path


class ThreadedHTTPServer(SocketServer.ThreadingMixIn,
                         BaseHTTPServer.HTTPServer):   pass

# -- Options

def configfile():
    appname = 'droopy'
    # os.name is 'posix', 'nt', 'os2', 'mac', 'ce' or 'riscos'
    if os.name == 'posix':
        filename = "%s/.%s" % (os.environ["HOME"], appname)

    elif os.name == 'mac':
        filename = ("%s/Library/Application Support/%s" %
                    (os.environ["HOME"], appname))

    elif os.name == 'nt':
        filename = ("%s\Application Data\%s" %
                    (os.environ["HOMEPATH"], appname))
    else:
        filename = None

    return filename


def save_options():
    opt = []
    if message:
        opt.append('--message=%s' % message.replace('\n', '\\n'))
    if picture:
        opt.append('--picture=%s' % picture)
    if directory:
        opt.append('--directory=%s' % directory)
    if port:
        opt.append('%d' % port)
    f = open(configfile(), 'w')
    f.write('\n'.join(opt).encode('utf8'))
    f.close()

    
def load_options():
    try:
        f = open(configfile())
        cmd = [line.strip().decode('utf8').replace('\\n', '\n')
               for line in f.readlines()]
        parse_args(cmd)
        f.close()
        return True
    except IOError, e:
        return False


def parse_args(cmd=None):
    """Parse command-line arguments.

    Parse sys.argv[1:] if no argument is passed.
    """
    global picture, message, port, directory, must_save_options

    if cmd == None:
        cmd = sys.argv[1:]
        lang, encoding = locale.getdefaultlocale()
        if encoding != None:
            cmd = [a.decode(encoding) for a in cmd]
            
    opts, args = None, None
    try:
        opts, args = getopt.gnu_getopt(cmd, "p:m:d:h",
                                       ["picture=","message=",
                                        "directory=", "help",
                                        "save-config","delete-config"])
    except Exception, e:
        print e
        sys.exit(1)

    for o,a in opts:
        if o in ["-p", "--picture"] :
            picture = os.path.expanduser(a)

        elif o in ["-m", "--message"] :
            message = a
                
        elif o in ['-d', '--directory']:
            directory = a
            
        elif o in ['--save-config']:
            must_save_options = True

        elif o in ['--delete-config']:
            try:
                filename = configfile()
                os.remove(filename)
                print 'Deleted ' + filename
            except Exception, e:
                print e
            sys.exit(0)

        elif o in ['-h', '--help']:
            print USAGE
            sys.exit(0)

    # port number
    try:
        if args[0:]:
            port = int(args[0])
    except ValueError:
        print args[0], "is not a valid port number"
        sys.exit(1)


# -- 

def run():
    """Run the webserver."""
    socket.setdefaulttimeout(3*60)
    server_address = ('', port)
    HTTPUploadHandler.protocol_version = "HTTP/1.0"
    httpd = ThreadedHTTPServer(server_address, HTTPUploadHandler)
    httpd.serve_forever()


if __name__ == '__main__':
    config_found = load_options()
    parse_args()

    if config_found:
        print 'Configuration found in %s' % configfile()
    else:
        print "No configuration file found."
        
    if must_save_options:
        save_options()
        print "Options saved in %s" % configfile()

    print "Files will be uploaded to %s" % directory
    try:
        print "HTTP server running... Check it out at http://localhost:%d"%port
        run()
    except KeyboardInterrupt:
        print '^C received, shutting down server'
        # some threads may run until they terminate
