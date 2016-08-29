#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Droopy (http://stackp.online.fr/droopy)
Copyright 2008-2013 (c) Pierre Duquesne <stackp@online.fr>
Licensed under the New BSD License.

Changelog
   20151025 * Global variables removed
            * Code refactoring and re-layout
            * Python 2 and 3 compatibility
            * Efficiency and Security improvements
            * Added --config-file option.
            * Retains backwards compatibility.
   20131121 * Update HTML/CSS for mobile devices
            * Add HTTPS support
            * Add HTTP basic authentication
            * Add option to change uploaded file permissions
            * Add support for HTML5 multiple file upload
   20120108 * Taiwanese translation by Li-cheng Hsu.
   20110928 * Correctly save message with --save-config. Fix by Sven Radde.
   20110708 * Polish translation by Jacek Politowski.
   20110625 * Fix bug regarding filesystem name encoding.
            * Save the --dl option when --save-config is passed.
   20110501 * Add the --dl option to let clients download files.
            * CSS speech bubble.
   20101130 * CSS and HTML update. Switch to the new BSD License.
   20100523 * Simplified Chinese translation by Ye Wei.
   20100521 * Hungarian translation by Csaba Szigetvári.
            * Russian translation by muromec.
            * Use %APPDATA% Windows environment variable -- fix by Maik.
   20091229 * Brazilian Portuguese translation by
              Carlos Eduardo Moreira dos Santos and Toony Poony.
            * IE layout fix by Carlos Eduardo Moreira dos Santos.
            * Galician translation by Miguel Anxo Bouzada.
   20090721 * Indonesian translation by Kemas.
   20090205 * Japanese translation by Satoru Matsumoto.
            * Slovak translation by CyberBoBaK.
   20090203 * Norwegian translation by Preben Olav Pedersen.
   20090202 * Korean translation by xissy.
            * Fix for unicode filenames by xissy.
            * Relies on 127.0.0.1 instead of "localhost" hostname.
   20090129 * Serbian translation by kotnik.
   20090125 * Danish translation by jan.
   20081210 * Greek translation by n2j3.
   20081128 * Slovene translation by david.
            * Romanian translation by Licaon.
   20081022 * Swedish translation by David Eurenius.
   20081001 * Droopy gets pretty (css and html rework).
            * Finnish translation by ipppe.
   20080926 * Configuration saving and loading.
   20080906 * Extract the file base name (some browsers send the full path).
   20080905 * File is uploaded directly into the specified directory.
   20080904 * Arabic translation by Djalel Chefrour.
            * Italian translation by fabius and d1s4st3r.
            * Dutch translation by Tonio Voerman.
            * Portuguese translation by Pedro Palma.
            * Turkish translation by Heartsmagic.
   20080727 * Spanish translation by Federico Kereki.
   20080624 * Option -d or --directory to specify the upload directory.
   20080622 * File numbering to avoid overwriting.
   20080620 * Czech translation by Jiří.
            * German translation by Michael.
   20080408 * First release.
"""
from __future__ import print_function
import sys
if sys.version_info >= (3, 0):
    from http import server as httpserver
    import socketserver
    from urllib import parse as urllibparse
    unicode = str
else:
    import BaseHTTPServer as httpserver
    import SocketServer as socketserver
    import urllib as urllibparse

import cgi
import os
import posixpath
import macpath
import ntpath
import argparse
import mimetypes
import shutil
import tempfile
import socket
import base64
import functools


def _decode_str_if_py2(inputstr, encoding='utf-8'):
    "Will return decoded with given encoding *if* input is a string and it's Py2."
    if sys.version_info < (3,) and isinstance(inputstr, str):
        return inputstr.decode(encoding)
    else:
        return inputstr

def _encode_str_if_py2(inputstr, encoding='utf-8'):
    "Will return encoded with given encoding *if* input is a string and it's Py2"
    if sys.version_info < (3,) and isinstance(inputstr, str):
        return inputstr.encode(encoding)
    else:
        return inputstr

def fullpath(path):
    "Shortcut for os.path abspath(expanduser())"
    return os.path.abspath(os.path.expanduser(path))

def basename(path):
    "Extract the file base name (some browsers send the full file path)."
    for mod in posixpath, macpath, ntpath:
        path = mod.basename(path)
    return path

def check_auth(method):
    "Wraps methods on the request handler to require simple auth checks."
    def decorated(self, *pargs):
        "Reject if auth fails."
        if self.auth:
            # TODO: Between minor versions this handles str/bytes differently
            received = self.get_case_insensitive_header('Authorization', None)
            expected = 'Basic ' + base64.b64encode(self.auth)
            # TODO: Timing attack?
            if received != expected:
                self.send_response(401)
                self.send_header('WWW-Authenticate', 'Basic realm=\"Droopy\"')
                self.send_header('Content-type', 'text/html')
                self.end_headers()
            else:
                method(self, *pargs)
        else:
            method(self, *pargs)
    functools.update_wrapper(decorated, method)
    return decorated


class Abort(Exception):
    "Used by handle to rethrow exceptions in ThreadedHTTPServer."


class DroopyFieldStorage(cgi.FieldStorage):
    """
    The file is created in the destination directory and its name is
    stored in the tmpfilename attribute.

    Adds a keyword-argument "directory", which is where files are to be
    stored. Because of CGI magic this might not be thread-safe.
    """

    TMPPREFIX = 'tmpdroopy'

    # Would love to do a **kwargs job here but cgi has some recursive
    # magic that passes all possible arguments positionally..
    def __init__(self, fp=None, headers=None, outerboundary=b'',
                 environ=os.environ, keep_blank_values=0, strict_parsing=0,
                 limit=None, encoding='utf-8', errors='replace',
                 directory='.'):
        """
        Adds 'directory' argument to FieldStorage.__init__.
        Retains compatibility with FieldStorage.__init__ (which involves magic)
        """
        self.directory = directory
        # Not only is cgi.FieldStorage full of magic, it's DIFFERENT
        # magic in Py2/Py3. Here's a case of the core library making
        # life difficult, in a class that's *supposed to be subclassed*!
        if sys.version_info > (3,):
            cgi.FieldStorage.__init__(self, fp, headers, outerboundary,
                                      environ, keep_blank_values,
                                      strict_parsing, limit, encoding, errors)
        else:
            cgi.FieldStorage.__init__(self, fp, headers, outerboundary,
                                      environ, keep_blank_values,
                                      strict_parsing)

    # Binary is passed in Py2 but not Py3.
    def make_file(self, binary=None):
        "Overrides builtin method to store tempfile in the set directory."
        fd, name = tempfile.mkstemp(dir=self.directory, prefix=self.TMPPREFIX)
        # Pylint doesn't like these if they're not declared in __init__ first,
        # but setting tmpfile there leads to odd errors where it's never re-set
        # to a file descriptor.
        self.tmpfile = os.fdopen(fd, 'w+b')
        self.tmpfilename = name
        return self.tmpfile


class HTTPUploadHandler(httpserver.BaseHTTPRequestHandler):
    "The guts of Droopy-a custom handler that accepts files & serves templates"

    @property
    def templates(self):
        "Ensure provided."
        raise NotImplementedError("Must set class with a templates dict!")

    @property
    def localisations(self):
        "Ensure provided."
        raise NotImplementedError("Must set class with a localisations dict!")

    @property
    def directory(self):
        "Ensure provided."
        raise NotImplementedError("Must provide directory to host.")

    message = ''
    picture = ''
    publish_files = False
    file_mode = None
    protocol_version = 'HTTP/1.0'
    form_field = 'upfile'
    auth = ''
    certfile = None
    divpicture = '<div class="box"><img src="/__droopy/picture"/></div>'

    def get_case_insensitive_header(self, hdrname, default):
        "Python 2 and 3 differ in header capitalisation!"
        lc_hdrname = hdrname.lower()
        lc_headers = dict((h.lower(), h) for h in self.headers.keys())
        if lc_hdrname in lc_headers:
            return self.headers[lc_headers[lc_hdrname]]
        else:
            return default

    @staticmethod
    def prefcode_tuple(prefcode):
        "Parse language preferences into (preference, language) tuples."
        prefbits = prefcode.split(";q=")
        if len(prefbits) == 1:
            return (1, prefbits[0])
        else:
            return (float(prefbits[1]), prefbits[0])

    def parse_accepted_languages(self):
        "Parse accept-language header"
        lhdr = self.get_case_insensitive_header('accept-language', default='')
        if lhdr:
            accepted = [self.prefcode_tuple(lang) for lang in lhdr.split(',')]
            accepted.sort()
            accepted.reverse()
            return [x[1] for x in accepted]
        else:
            return []

    def choose_language(self):
        "Choose localisation based on accept-language header (default 'en')"
        accepted = self.parse_accepted_languages()
        # -- Choose the appropriate translation dictionary (default is english)
        lang = "en"
        for alang in accepted:
            if alang in self.localisations:
                lang = alang
                break
        return self.localisations[lang]

    def html(self, page):
        """
        page can be "main", "success", or "error"
        returns an html page (in the appropriate language) as a string
        """
        dico = {}
        dico.update(self.choose_language())
        # -- Set message and picture
        if self.message:
            dico['message'] = '<div id="message">{0}</div>'.format(self.message)
        else:
            dico["message"] = ''
        # The default appears to be missing/broken, so needs a bit of love anyway.
        if self.picture:
            dico["divpicture"] = self.divpicture
        else:
            dico["divpicture"] = ''
        # -- Possibly provide download links
        # TODO: Sanity-check for injections
        links = ''
        if self.publish_files:
            for name in self.published_files():
                encoded_name = urllibparse.quote(_encode_str_if_py2(name))
                links += '<a href="/{0}">{1}</a>'.format(encoded_name, name)
            links = '<div id="files">' + links + '</div>'
        dico["files"] = links
        # -- Add a link to discover the url
        if self.client_address[0] == "127.0.0.1":
            dico["port"] = self.server.server_port
            dico["ssl"] = int(self.certfile is not None)
            dico["linkurl"] = self.templates['linkurl'] % dico
        else:
            dico["linkurl"] = ''
        return self.templates[page] % dico

    @check_auth
    def do_GET(self):
        "Standard method to override in this Server object."
        name = self.path.lstrip('/')
        name = urllibparse.unquote(name)
        name = _decode_str_if_py2(name, 'utf-8')

        # TODO: Refactor special-method handling to make more modular?
        # Include ability to self-define "special method" prefix path?
        if self.picture != None and self.path == '/__droopy/picture':
            # send the picture
            self.send_file(self.picture)
        # TODO Verify that this is path-injection proof
        elif name in self.published_files():
            localpath = os.path.join(self.directory, name)
            self.send_file(localpath)
        else:
            self.send_html(self.html("main"))

    @check_auth
    def do_POST(self):
        "Standard method to override in this Server object."
        try:
            self.log_message("Started file transfer")
            # -- Save file (numbered to avoid overwriting, ex: foo-3.png)
            form = DroopyFieldStorage(fp=self.rfile,
                                      directory=self.directory,
                                      headers=self.headers,
                                      environ={'REQUEST_METHOD': self.command})
            file_items = form[self.form_field]
            #-- Handle multiple file upload
            if not isinstance(file_items, list):
                file_items = [file_items]
            for item in file_items:
                filename = _decode_str_if_py2(basename(item.filename), "utf-8")
                if filename == "":
                    continue
                localpath = _encode_str_if_py2(os.path.join(self.directory, filename), "utf-8")
                root, ext = os.path.splitext(localpath)
                i = 1
                # TODO: race condition...
                while os.path.exists(localpath):
                    localpath = "%s-%d%s" % (root, i, ext)
                    i = i + 1
                if hasattr(item, 'tmpfile'):
                    # DroopyFieldStorage.make_file() has been called
                    item.tmpfile.close()
                    shutil.move(item.tmpfilename, localpath)
                else:
                    # no temporary file, self.file is a StringIO()
                    # see cgi.FieldStorage.read_lines()
                    with open(localpath, "wb") as fout:
                        shutil.copyfileobj(item.file, fout)
                if self.file_mode is not None:
                    os.chmod(localpath, self.file_mode)
                self.log_message("Received: %s", os.path.basename(localpath))

            # -- Reply
            if self.publish_files:
                # The file list gives a feedback for the upload success
                self.send_resp_headers(301, {'Location': '/'}, end=True)
            else:
                self.send_html(self.html("success"))

        except Exception as e:
            self.log_message(repr(e))
            self.send_html(self.html("error"))
            # raise e  # Dev only

    def send_resp_headers(self, response_code, headers_dict, end=False):
        "Just a shortcut for a common operation."
        self.send_response(response_code)
        for k, v in headers_dict.items():
            self.send_header(k, v)
        if end:
            self.end_headers()

    def send_html(self, htmlstr):
        "Simply returns htmlstr with the appropriate content-type/status."
        self.send_resp_headers(200, {'Content-type': 'text/html; charset=utf-8'}, end=True)
        self.wfile.write(htmlstr.encode("utf-8"))

    def send_file(self, localpath):
        "Does what it says on the tin! Includes correct content-type/length."
        with open(localpath, 'rb') as f:
            self.send_resp_headers(200,
                                   {'Content-length': os.fstat(f.fileno())[6],
                                    'Content-type': mimetypes.guess_type(localpath)[0]},
                                   end=True)
            shutil.copyfileobj(f, self.wfile)

    def published_files(self):
        "Returns the list of files that should appear as download links."
        names = []
        # In py2, listdir() returns strings when the directory is a string.
        for name in os.listdir(unicode(self.directory)):
            if name.startswith(DroopyFieldStorage.TMPPREFIX):
                continue
            npath = os.path.join(self.directory, name)
            if os.path.isfile(npath):
                names.append(name)
        names.sort(key=lambda s: s.lower())
        return names

    def handle(self):
        "Lets parent object handle, but redirects socket exceptions as 'Abort's."
        try:
            httpserver.BaseHTTPRequestHandler.handle(self)
        except socket.error as e:
            self.log_message(str(e))
            raise Abort(str(e))


class ThreadedHTTPServer(socketserver.ThreadingMixIn,
                         httpserver.HTTPServer):
    "Allows propagation of socket.error in HTTPUploadHandler.handle"
    def handle_error(self, request, client_address):
        "Override socketserver.handle_error"
        exctype = sys.exc_info()[0]
        if not exctype is Abort:
            httpserver.HTTPServer.handle_error(self, request, client_address)


def run(hostname='',
        port=80,
        templates=None,
        localisations=None,
        directory='.',
        timeout=3*60,
        picture=None,
        message='',
        file_mode=None,
        publish_files=False,
        auth='',
        certfile=None,
        permitted_ciphers=(
            'ECDH+AESGCM:ECDH+AES256:ECDH+AES128:ECDH+3DES'
            ':RSA+AESGCM:RSA+AES:RSA+3DES'
            ':!aNULL:!MD5:!DSS')):
    """
    certfile should be the path of a PEM TLS certificate.

    permitted_ciphers, if a TLS cert is provided, is an OpenSSL cipher string.
    The default here is taken from:
      https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
    ..with DH-only ciphers removed because of precomputation hazard.
    """
    if templates is None or localisations is None:
        raise ValueError("Must provide templates *and* localisations.")
    socket.setdefaulttimeout(timeout)
    HTTPUploadHandler.templates = templates
    HTTPUploadHandler.directory = directory
    HTTPUploadHandler.localisations = localisations
    HTTPUploadHandler.certfile = certfile
    HTTPUploadHandler.publish_files = publish_files
    HTTPUploadHandler.picture = picture
    HTTPUploadHandler.message = message
    HTTPUploadHandler.file_mode = file_mode
    HTTPUploadHandler.auth = auth
    httpd = ThreadedHTTPServer((hostname, port), HTTPUploadHandler)
    # TODO: Specify TLS1.2 only?
    if certfile:
        try:
            import ssl
        except:
            print("Error: Could not import module 'ssl', exiting.")
            sys.exit(2)
        httpd.socket = ssl.wrap_socket(
            httpd.socket,
            certfile=certfile,
            ciphers=permitted_ciphers,
            server_side=True)
    httpd.serve_forever()

# -- Dato

# -- HTML templates

style = '''
<meta name="viewport"
      content="width=device-width,initial-scale=1,maximum-scale=1" />
<style type="text/css">
<!--
* {margin: 0; padding: 0;}
body {text-align: center; background-color: #eee; font-family: sans-serif;
      color:#777;}
div {word-wrap: break-word;}
img {max-width: 100%%;}
a {color: #4499cc; text-decoration: none;}
.container {max-width: 700px; margin: auto; background-color: #fff;}
.box {padding-top: 20px; padding-bottom: 20px;}
#linkurl {background-color: #333;}
#linkurl a {color: #ddd; text-decoration: none;}
#linkurl a:hover {color: #fff;}
#message {padding: 5px 0; font-size: 2em; font-weight: lighter;
          letter-spacing: -2px; line-height: 50px; color: #aaa;}
#sending {display: none; font-style: italic;}
#sending .text {padding-top: 10px; color: #bbb; font-size: 0.8em;}
#wrapform {height: 90px; padding-top:40px;}
#progress {display: inline;  border-collapse: separate; empty-cells: show;
           border-spacing: 24px 0; padding: 0; vertical-align: bottom;}
#progress td {height: 17px; width: 17px; background-color: #eee;
              padding: 0px; border-radius: 90px; box-shadow: 0 0 3px #bbb;}
#userinfo {padding-bottom: 20px;}
#files {
  margin: auto;
  padding: 13px 0;
  text-align: left;
  overflow: auto;
  margin-bottom: 20px;
}
#files a {text-decoration: none; display: block; padding: 10px 20px;}
#files a:nth-child(2n+1) {background-color: #F7F7F7;}
#files a:link {color: #4499cc}
#files a:visited {color: #a0c0e0}
#files a:hover {background-color:#f0f0f0}
--></style>'''

userinfo = '''
<div id="userinfo">
  %(message)s
  %(divpicture)s
</div>
'''

maintmpl = '''
<!doctype html>
<html>
<head>
<title>%(maintitle)s</title>
''' + style + '''
<script language="JavaScript">
function swap() {
   document.getElementById("form").style.display = "none";
   document.getElementById("sending").style.display = "block";
   pulse(0);
}

function pulse(i) {
    var NUMCELL = 5;
    var cell = document.getElementById("cell-" + (i %% NUMCELL));
    var prev = document.getElementById("cell-"+((i - 1 + NUMCELL) %% NUMCELL));
    cell.style.backgroundColor = "#7ac";
    prev.style.backgroundColor = "#eee";
    setTimeout(function() {pulse(i+1);}, 300);
}

function onunload() {
   document.getElementById("form").style.display = "block";
   document.getElementById("sending").style.display = "none";
}
</script></head>
<body>
%(linkurl)s
<div class="container">
<div id="wrapform">
  <div id="form" class="box">
    <form method="post" enctype="multipart/form-data" action="">
      <input name="upfile" type="file" multiple="yes">
      <input value="%(submit)s" onclick="swap()" type="submit">
    </form>
  </div>
  <div id="sending" class="box">
    <table id="progress">
      <tr>
        <td id="cell-0"/><td id="cell-1"/><td id="cell-2"/>
        <td id="cell-3"/><td id="cell-4"/>
      </tr>
    </table>
    <div class="text">%(sending)s</div>
  </div>
</div>
''' + userinfo + '''
%(files)s
</div>
</body>
</html>
'''

successtmpl = '''
<!doctype html>
<html>
<head><title> %(successtitle)s </title>
''' + style + '''
</head>
<body>
<div class="container">
<div id="wrapform">
  <div class="box">
    %(received)s
    <a href="/"> %(another)s </a>
  </div>
</div>
''' + userinfo + '''
</div>
</body>
</html>
'''

errortmpl = '''
<!doctype html>
<html>
<head><title> %(errortitle)s </title>
''' + style + '''
</head>
<body>
<div class="container">
<div id="wrapform">
  <div class="box">
    %(problem)s
    <a href="/"> %(retry)s </a>
  </div>
</div>
''' + userinfo + '''
</div>
</body>
</html>
'''

linkurltmpl = '''<div id="linkurl" class="box">
<a href="http://stackp.online.fr/droopy-ip.php?port=%(port)d&ssl=%(ssl)d"> %(discover)s
</a></div>'''


default_templates = {
    "main":     maintmpl,
    "success":  successtmpl,
    "error":    errortmpl,
    "linkurl":  linkurltmpl}

# -- Translations
default_localisations = {
    'ar' : {
        "maintitle":       u"إرسال ملف",
        "submit":          u"إرسال",
        "sending":         u"الملف قيد الإرسال",
        "successtitle":    u"تم استقبال الملف",
        "received":        u"تم استقبال الملف !",
        "another":         u"إرسال ملف آخر",
        "errortitle":      u"مشكلة",
        "problem":         u"حدثت مشكلة !",
        "retry":           u"إعادة المحاولة",
        "discover":        u"اكتشاف عنوان هذه الصفحة"},
    'cs' : {
        "maintitle":       u"Poslat soubor",
        "submit":          u"Poslat",
        "sending":         u"Posílám",
        "successtitle":    u"Soubor doručen",
        "received":        u"Soubor doručen !",
        "another":         u"Poslat další soubor",
        "errortitle":      u"Chyba",
        "problem":         u"Stala se chyba !",
        "retry":           u"Zkusit znova.",
        "discover":        u"Zjistit adresu stránky"},
    'da' : {
        "maintitle":       u"Send en fil",
        "submit":          u"Send",
        "sending":         u"Sender",
        "successtitle":    u"Fil modtaget",
        "received":        u"Fil modtaget!",
        "another":         u"Send en fil til.",
        "errortitle":      u"Problem",
        "problem":         u"Det er opstået en fejl!",
        "retry":           u"Forsøg igen.",
        "discover":        u"Find adressen til denne side"},
    'de' : {
        "maintitle":       "Datei senden",
        "submit":          "Senden",
        "sending":         "Sendet",
        "successtitle":    "Datei empfangen",
        "received":        "Datei empfangen!",
        "another":         "Weitere Datei senden",
        "errortitle":      "Fehler",
        "problem":         "Ein Fehler ist aufgetreten!",
        "retry":           "Wiederholen",
        "discover":        "Internet-Adresse dieser Seite feststellen"},
    'el' : {
        "maintitle":       u"Στείλε ένα αρχείο",
        "submit":          u"Αποστολή",
        "sending":         u"Αποστέλλεται...",
        "successtitle":    u"Επιτυχής λήψη αρχείου ",
        "received":        u"Λήψη αρχείου ολοκληρώθηκε",
        "another":         u"Στείλε άλλο ένα αρχείο",
        "errortitle":      u"Σφάλμα",
        "problem":         u"Παρουσιάστηκε σφάλμα",
        "retry":           u"Επανάληψη",
        "discover":        u"Βρες την διεύθυνση της σελίδας"},
    'en' : {
        "maintitle":       "Send a file",
        "submit":          "Send",
        "sending":         "Sending",
        "successtitle":    "File received",
        "received":        "File received!",
        "another":         "Send another file.",
        "errortitle":      "Problem",
        "problem":         "There has been a problem!",
        "retry":           "Retry.",
        "discover":        "Discover the address of this page"},
    'es' : {
        "maintitle":       u"Enviar un archivo",
        "submit":          u"Enviar",
        "sending":         u"Enviando",
        "successtitle":    u"Archivo recibido",
        "received":        u"¡Archivo recibido!",
        "another":         u"Enviar otro archivo.",
        "errortitle":      u"Error",
        "problem":         u"¡Hubo un problema!",
        "retry":           u"Reintentar",
        "discover":        u"Descubrir la dirección de esta página"},
    'fi' : {
        "maintitle":       u"Lähetä tiedosto",
        "submit":          u"Lähetä",
        "sending":         u"Lähettää",
        "successtitle":    u"Tiedosto vastaanotettu",
        "received":        u"Tiedosto vastaanotettu!",
        "another":         u"Lähetä toinen tiedosto.",
        "errortitle":      u"Virhe",
        "problem":         u"Virhe lahetettäessä tiedostoa!",
        "retry":           u"Uudelleen.",
        "discover":        u"Näytä tämän sivun osoite"},
    'fr' : {
        "maintitle":       u"Envoyer un fichier",
        "submit":          u"Envoyer",
        "sending":         u"Envoi en cours",
        "successtitle":    u"Fichier reçu",
        "received":        u"Fichier reçu !",
        "another":         u"Envoyer un autre fichier.",
        "errortitle":      u"Problème",
        "problem":         u"Il y a eu un problème !",
        "retry":           u"Réessayer.",
        "discover":        u"Découvrir l'adresse de cette page"},
    'gl' : {
        "maintitle":       u"Enviar un ficheiro",
        "submit":          u"Enviar",
        "sending":         u"Enviando",
        "successtitle":    u"Ficheiro recibido",
        "received":        u"Ficheiro recibido!",
        "another":         u"Enviar outro ficheiro.",
        "errortitle":      u"Erro",
        "problem":         u"Xurdíu un problema!",
        "retry":           u"Reintentar",
        "discover":        u"Descubrir o enderezo desta páxina"},
    'hu' : {
        "maintitle":       u"Állomány küldése",
        "submit":          u"Küldés",
        "sending":         u"Küldés folyamatban",
        "successtitle":    u"Az állomány beérkezett",
        "received":        u"Az állomány beérkezett!",
        "another":         u"További állományok küldése",
        "errortitle":      u"Hiba",
        "problem":         u"Egy hiba lépett fel!",
        "retry":           u"Megismételni",
        "discover":        u"Az oldal Internet-címének megállapítása"},
    'id' : {
        "maintitle":       "Kirim sebuah berkas",
        "submit":          "Kirim",
        "sending":         "Mengirim",
        "successtitle":    "Berkas diterima",
        "received":        "Berkas diterima!",
        "another":         "Kirim berkas yang lain.",
        "errortitle":      "Permasalahan",
        "problem":         "Telah ditemukan sebuah kesalahan!",
        "retry":           "Coba kembali.",
        "discover":        "Kenali alamat IP dari halaman ini"},
    'it' : {
        "maintitle":       u"Invia un file",
        "submit":          u"Invia",
        "sending":         u"Invio in corso",
        "successtitle":    u"File ricevuto",
        "received":        u"File ricevuto!",
        "another":         u"Invia un altro file.",
        "errortitle":      u"Errore",
        "problem":         u"Si è verificato un errore!",
        "retry":           u"Riprova.",
        "discover":        u"Scopri l’indirizzo di questa pagina"},
    'ja' : {
        "maintitle":       u"ファイル送信",
        "submit":          u"送信",
        "sending":         u"送信中",
        "successtitle":    u"受信完了",
        "received":        u"ファイルを受信しました！",
        "another":         u"他のファイルを送信する",
        "errortitle":      u"問題発生",
        "problem":         u"問題が発生しました！",
        "retry":           u"リトライ",
        "discover":        u"このページのアドレスを確認する"},
    'ko' : {
        "maintitle":       u"파일 보내기",
        "submit":          u"보내기",
        "sending":         u"보내는 중",
        "successtitle":    u"파일이 받아졌습니다",
        "received":        u"파일이 받아졌습니다!",
        "another":         u"다른 파일 보내기",
        "errortitle":      u"문제가 발생했습니다",
        "problem":         u"문제가 발생했습니다!",
        "retry":           u"다시 시도",
        "discover":        u"이 페이지 주소 알아보기"},
    'nl' : {
        "maintitle":       "Verstuur een bestand",
        "submit":          "Verstuur",
        "sending":         "Bezig met versturen",
        "successtitle":    "Bestand ontvangen",
        "received":        "Bestand ontvangen!",
        "another":         "Verstuur nog een bestand.",
        "errortitle":      "Fout",
        "problem":         "Er is een fout opgetreden!",
        "retry":           "Nog eens.",
        "discover":        "Vind het adres van deze pagina"},
    'no' : {
        "maintitle":       u"Send en fil",
        "submit":          u"Send",
        "sending":         u"Sender",
        "successtitle":    u"Fil mottatt",
        "received":        u"Fil mottatt !",
        "another":         u"Send en ny fil.",
        "errortitle":      u"Feil",
        "problem":         u"Det har skjedd en feil !",
        "retry":           u"Send på nytt.",
        "discover":        u"Finn addressen til denne siden"},
    'pl' : {
        "maintitle":       u"Wyślij plik",
        "submit":          u"Wyślij",
        "sending":         u"Wysyłanie",
        "successtitle":    u"Plik wysłany",
        "received":        u"Plik wysłany!",
        "another":         u"Wyślij kolejny plik.",
        "errortitle":      u"Problem",
        "problem":         u"Wystąpił błąd!",
        "retry":           u"Spróbuj ponownie.",
        "discover":        u"Znajdź adres tej strony"},
    'pt' : {
        "maintitle":       u"Enviar um ficheiro",
        "submit":          u"Enviar",
        "sending":         u"A enviar",
        "successtitle":    u"Ficheiro recebido",
        "received":        u"Ficheiro recebido !",
        "another":         u"Enviar outro ficheiro.",
        "errortitle":      u"Erro",
        "problem":         u"Ocorreu um erro !",
        "retry":           u"Tentar novamente.",
        "discover":        u"Descobrir o endereço desta página"},
    'pt-br' : {
        "maintitle":       u"Enviar um arquivo",
        "submit":          u"Enviar",
        "sending":         u"Enviando",
        "successtitle":    u"Arquivo recebido",
        "received":        u"Arquivo recebido!",
        "another":         u"Enviar outro arquivo.",
        "errortitle":      u"Erro",
        "problem":         u"Ocorreu um erro!",
        "retry":           u"Tentar novamente.",
        "discover":        u"Descobrir o endereço desta página"},
    'ro' : {
        "maintitle":       u"Trimite un fişier",
        "submit":          u"Trimite",
        "sending":         u"Se trimite",
        "successtitle":    u"Fişier recepţionat",
        "received":        u"Fişier recepţionat !",
        "another":         u"Trimite un alt fişier.",
        "errortitle":      u"Problemă",
        "problem":         u"A intervenit o problemă !",
        "retry":           u"Reîncearcă.",
        "discover":        u"Descoperă adresa acestei pagini"},
    'ru' : {
        "maintitle":       u"Отправить файл",
        "submit":          u"Отправить",
        "sending":         u"Отправляю",
        "successtitle":    u"Файл получен",
        "received":        u"Файл получен !",
        "another":         u"Отправить другой файл.",
        "errortitle":      u"Ошибка",
        "problem":         u"Произошла ошибка !",
        "retry":           u"Повторить.",
        "discover":        u"Посмотреть адрес этой страницы"},
    'sk' : {
        "maintitle":       u"Pošli súbor",
        "submit":          u"Pošli",
        "sending":         u"Posielam",
        "successtitle":    u"Súbor prijatý",
        "received":        u"Súbor prijatý !",
        "another":         u"Poslať ďalší súbor.",
        "errortitle":      u"Chyba",
        "problem":         u"Vyskytla sa chyba!",
        "retry":           u"Skúsiť znova.",
        "discover":        u"Zisti adresu tejto stránky"},
    'sl' : {
        "maintitle":       u"Pošlji datoteko",
        "submit":          u"Pošlji",
        "sending":         u"Pošiljam",
        "successtitle":    u"Datoteka prejeta",
        "received":        u"Datoteka prejeta !",
        "another":         u"Pošlji novo datoteko.",
        "errortitle":      u"Napaka",
        "problem":         u"Prišlo je do napake !",
        "retry":           u"Poizkusi ponovno.",
        "discover":        u"Poišči naslov na tej strani"},
    'sr' : {
        "maintitle":       u"Pošalji fajl",
        "submit":          u"Pošalji",
        "sending":         u"Šaljem",
        "successtitle":    u"Fajl primljen",
        "received":        u"Fajl primljen !",
        "another":         u"Pošalji još jedan fajl.",
        "errortitle":      u"Problem",
        "problem":         u"Desio se problem !",
        "retry":           u"Pokušaj ponovo.",
        "discover":        u"Otkrij adresu ove stranice"},
    'sv' : {
        "maintitle":       u"Skicka en fil",
        "submit":          u"Skicka",
        "sending":         u"Skickar...",
        "successtitle":    u"Fil mottagen",
        "received":        u"Fil mottagen !",
        "another":         u"Skicka en fil till.",
        "errortitle":      u"Fel",
        "problem":         u"Det har uppstått ett fel !",
        "retry":           u"Försök igen.",
        "discover":        u"Ta reda på adressen till denna sida"},
    'tr' : {
        "maintitle":       u"Dosya gönder",
        "submit":          u"Gönder",
        "sending":         u"Gönderiliyor...",
        "successtitle":    u"Gönderildi",
        "received":        u"Gönderildi",
        "another":         u"Başka bir dosya gönder.",
        "errortitle":      u"Problem.",
        "problem":         u"Bir problem oldu !",
        "retry":           u"Yeniden dene.",
        "discover":        u"Bu sayfanın adresini bul"},
    'zh-cn' : {
        "maintitle":       u"发送文件",
        "submit":          u"发送",
        "sending":         u"发送中",
        "successtitle":    u"文件已收到",
        "received":        u"文件已收到！",
        "another":         u"发送另一个文件。",
        "errortitle":      u"问题",
        "problem":         u"出现问题！",
        "retry":           u"重试。",
        "discover":        u"查看本页面的地址"},
    'zh-tw' : {
        "maintitle":       u"上傳檔案",
        "submit":          u"上傳",
        "sending":         u"傳送中...",
        "successtitle":    u"已收到檔案",
        "received":        u"已收到檔案！",
        "another":         u"上傳另一個檔案。",
        "errortitle":      u"錯誤",
        "problem":         u"出現錯誤！",
        "retry":           u"重試。",
        "discover":        u"查閱本網頁的網址"}
}  # Ends default_localisations dictionary.


# -- Options

def default_configfile():
    "Returns appropriate absolute path to configfile, per-platform."
    appname = 'droopy'
    if os.name == 'posix':
        filename = os.path.join(os.environ['HOME'], "." + appname)
    elif os.name == 'mac':
        filename = os.path.join(os.environ['HOME'], 'Library', 'Application Support', appname)
    elif os.name == 'nt':
        filename = os.path.join(os.environ['APPDATA'], appname)
    else:
        # Exaggerated shrug
        filename = './' + appname
    return filename


def save_options(cfg):
    "Dumps sys.argv with one argument per line."
    with open(cfg, "w") as O:
        ignorenext = False
        for opt in sys.argv[1:]:
            if ignorenext:
                ignorenext = False
                continue
            if opt.startswith("-"):
                if opt.strip() in ("--save-config", "--delete-config"):
                    continue
                if opt.strip() == '--config-file':
                    ignorenext = True
                    continue
                O.write("\n")
            else:
                O.write(" ")
            O.write(opt)


def load_options(cfg_loc):
    """
    Attempts to open location, piece lines back together into a terminal-style
    invocation, and pass to parse_args.
    """
    try:
        with open(cfg_loc) as f:
            cmd = []
            for line in f:
                line = line.strip()
                if not line:
                    continue
                if line.startswith("-"):
                    if " " in line:
                        opt, rest = line.split(" ", 1)
                        cmd.extend((opt, rest))
                    else:
                        cmd.append(line)
                else:
                    cmd.append(line)
        return parse_args(cmd)
    except IOError:
        return {}


def parse_args(cmd=None, ignore_defaults=False):
    "Parse terminal-style args list,  or sys.argv[1:] if no argument is passed."
    parser = argparse.ArgumentParser(
        description="Usage: droopy [options] [PORT]",
        epilog='Example:\n    droopy -m "Hi, this is Bob. You can send me a file." -p avatar.png'
    )
    parser.add_argument("port", type=int, nargs='?', default=8000,
                        help='port number to host droopy upon')
    parser.add_argument('-d', '--directory', type=str, default='.',
                        help='set the directory to upload files to')
    parser.add_argument('-m', '--message', type=str, default='',
                        help='set the message')
    parser.add_argument('-p', '--picture', type=str, default='',
                        help='set the picture')
    parser.add_argument('--publish-files', '--dl', action='store_true', default=False,
                        help='provide download links')
    parser.add_argument('-a', '--auth', type=str, default='',
                        help='set the authentication credentials, in form USER:PASS')
    parser.add_argument('--ssl', type=str, default='',
                        help='set up https using the certificate file')
    parser.add_argument('--chmod', type=str, default=None,
                        help='set the file permissions (octal value)')
    parser.add_argument('--save-config', action='store_true', default=False,
                        help='save options in a configuration file')
    parser.add_argument('--delete-config', action='store_true', default=False,
                        help='delete the configuration file and exit')
    parser.add_argument('--config-file', default=default_configfile(),
                        help='configuration file to load terminal arguments from.')
    args = parser.parse_args(cmd)
    if args.picture:
        if os.path.exists(args.picture):
            args.picture = fullpath(args.picture)
        else:
            print("Picture not found: '{0}'".format(args.picture))
    if args.delete_config:
        filename = default_configfile()
        os.remove(filename)
        print('Deleted ' + filename)
        sys.exit(0)
    if args.auth:
        if ':' not in args.auth:
            print("Error: authentication credentials must be "
                  "specified as USER:PASSWORD")
            sys.exit(1)
    if args.ssl:
        if not os.path.isfile(args.ssl):
            print("PEM file not found: '{0}'".format(args.ssl))
            sys.exit(1)
        args.ssl = fullpath(args.ssl)
    if args.chmod is not None:
        try:
            args.chmod = int(args.chmod, 8)
        except ValueError:
            print("Invalid octal value passed to chmod option: '{0}'".format(args.chmod))
            sys.exit(1)
    # Needs to be set after de-defaulting because CWD varies, obviously. :)
    args.directory = fullpath(args.directory)
    d_args = vars(args)
    if ignore_defaults:
        default_set = parse_args([])
        for k, v in default_set.items():
            if v == d_args[k]:
                del d_args[k]
    return d_args


def main():
    "Encapsulating main prevents scope leakage and pleases linters."
    print('''\
     _____
    |     \.----.-----.-----.-----.--.--.
    |  --  |   _|  _  |  _  |  _  |  |  |
    |_____/|__| |_____|_____|   __|___  |
                            |__|  |_____|
    ''')
    term_args = parse_args(ignore_defaults=True)
    cfg = term_args.get('config_file', default_configfile())
    args = load_options(cfg)
    if args:
        print("Configuration found in {0}".format(cfg))
        args.update(term_args)
    else:
        print("No configuration file found")
        args.update(parse_args(ignore_defaults=False))
    if args['save_config']:
        cfg = args.get('config_file', default_configfile())
        save_options(cfg)
        print("Options saved in {0}".format(cfg))
    print("Files will be uploaded to {0}\n".format(args['directory']))
    proto = 'https' if args['ssl'] else 'http'
    print("HTTP server starting...",
          "Check it out at {0}://localhost:{1}".format(proto, args['port']))
    try:
        run(port=args['port'],
            certfile=args['ssl'],
            picture=args['picture'],
            message=args['message'],
            directory=args['directory'],
            file_mode=args['chmod'],
            publish_files=args['publish_files'],
            auth=args['auth'],
            templates=default_templates,
            localisations=default_localisations)
    except KeyboardInterrupt:
        print('^C received, awaiting termination of remaining server threads..')

if __name__ == '__main__':
    main()
