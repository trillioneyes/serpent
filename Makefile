main.js: *.idr
	idris -p effects --codegen javascript -o main.js Main.idr
