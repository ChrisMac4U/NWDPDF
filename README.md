# NWDPDF
An Objective-C Class designed to access text in generated (not scanned) PDFs

Extracting text from a generated PDF (*not* a scanned one) is a fairly complicated task. I wasn't able to find any good libraries in Objective-C, so I wrote this class to give me somewhere to start. 

The [PDF spec][1] allows for text to be double encoded. First, characters are encoded in hexadecimal ('A' == 0x41, for example). Then each digit is itself encoded in ASCII ('A', for example, would be encoded as 0x34 0x31). This is bonkers, but that is how you do it. To see an example, find a PDF that was generated from a text based source and open it in BBEdit or similar application. 

I created this class to help find objects in the PDF, and to help decode some of it. You will most likely need to subclass NWDPDF to fit our specific needs. 

[1]: http://www.adobe.com/devnet/pdf/pdf_reference.html
