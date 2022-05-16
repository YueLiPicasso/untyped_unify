BASE=untyped_unify
INTF=$(BASE).mli
SRC=$(INTF) $(BASE).ml
DOCDIR=html_doc
STY=style.css
ODO=-html -colorize-code -css-style $(STY) -d ./$(DOCDIR)

untyped_unify.cmo : $(SRC)
	ocamlc -c $^

.PHONY : clean doc

doc :
	ocamldoc $(ODO) $(INTF)

clean :
	rm -f *.cmo *.cmi *.o ./$(DOCDIR)/*.html
