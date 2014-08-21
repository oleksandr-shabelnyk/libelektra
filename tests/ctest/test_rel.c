/***************************************************************************
 *          test_rel.c  -  Relation between keys
 *                  -------------------
 *  begin                : Wed 19 May, 2010
 *  copyright            : (C) 2010 by Markus Raab
 *  email                : elektra@markus-raab.org
 ****************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the BSD License (revised).                      *
 *                                                                         *
 ***************************************************************************/

#include <tests.h>

static void test_equal()
{
	printf ("check if equal\n");

	Key *k1 = keyNew(0);
	Key *k2 = keyNew(0);

	succeed_if (keyCmp (0,0)    == 0, "null pointers should be same");
	succeed_if (keyCmp (k1, k2) == 0, "should be same");

	keySetName (k1, ""); keySetName (k2, "");
	succeed_if (keyCmp (k1, k2) == 0, "should be same");

	keySetName (k1, "user"); keySetName (k2, "user");
	succeed_if (keyCmp (k1, k2) == 0, "should be same");

	keySetName (k1, "system"); keySetName (k2, "system");
	succeed_if (keyCmp (k1, k2) == 0, "should be same");

	keySetName (k1, "user/a"); keySetName (k2, "user/a");
	succeed_if (keyCmp (k1, k2) == 0, "should be same");

	keySetName (k1, "user/tests/simple"); keySetName (k2, "user/tests/simple/below");
	succeed_if (keyRel (k1, k2) >= 0, "should be below");
	succeed_if (keyRel (k1, k2) == 1, "should be below");

	keyDel (k1);
	keyDel (k2);
}

static void test_directbelow()
{
	printf ("check if direct below\n");
	Key *k1 = keyNew(0);
	Key *k2 = keyNew(0);

	keySetName (k1, "user"); keySetName (k2, "user/a");
	succeed_if (keyRel (k1, k2) == 1, "should be direct below");

	keySetName (k1, "system"); keySetName (k2, "system/a");
	succeed_if (keyRel (k1, k2) == 1, "should be direct below");

	keySetName (k1, "user"); keySetName (k2, "user/longer_name");
	succeed_if (keyRel (k1, k2) == 1, "should be direct below");

	keySetName (k1, "system"); keySetName (k2, "system/longer_name");
	succeed_if (keyRel (k1, k2) == 1, "should be direct below");

	keySetName (k1, "user/a"); keySetName (k2, "user/a/a");
	succeed_if (keyRel (k1, k2) == 1, "should be direct below");

	keySetName (k1, "system/a"); keySetName (k2, "system/a/a");
	succeed_if (keyRel (k1, k2) == 1, "should be direct below");


	keyDel (k1);
	keyDel (k2);
}

static void test_below()
{
	printf ("check if below\n");
	Key *k1 = keyNew(0);
	Key *k2 = keyNew(0);

	keySetName (k1, "user"); keySetName (k2, "user/a/a");
	succeed_if (keyRel (k1, k2) == 2, "should be below");

	keySetName (k1, "system"); keySetName (k2, "system/a/a");
	succeed_if (keyRel (k1, k2) == 2, "should be below");

	keySetName (k1, "user"); keySetName (k2, "user/longer_name/also_longer_name");
	succeed_if (keyRel (k1, k2) == 2, "should be below");

	keySetName (k1, "system"); keySetName (k2, "system/longer_name/also_longer_name");
	succeed_if (keyRel (k1, k2) == 2, "should be below");

	keySetName (k1, "user/a"); keySetName (k2, "user/a/a/a/a/a/a");
	succeed_if (keyRel (k1, k2) == 2, "should be below");

	keySetName (k1, "system/a"); keySetName (k2, "system/a/a/a/a/a/a");
	succeed_if (keyRel (k1, k2) == 2, "should be below");


	keyDel (k1);
	keyDel (k2);
}

static void test_examples()
{
	printf ("check examples\n");
	Key *key = keyNew(0);
	Key *check = keyNew(0);

	keySetName (key, "user/key/folder");
	keySetName (check, "user/key/folder");
	succeed_if (keyRel (key, check) == 0, "should be same");

	keySetName (key, "user/key/folder");
	keySetName (check, "user/key/folder/child");
	succeed_if (keyRel (key, check) == 1, "should be direct below");

	keySetName (key, "user/key/folder");
	keySetName (check, "user/key/folder/any/depth/deeper/grand-child");
	succeed_if (keyRel (key, check) == 2, "should be below (but not direct)");
	succeed_if (keyRel (key, check) > 0, "should be below");
	succeed_if (keyRel (key, check) >= 0, "should be the same or below");

	keySetName (key, "user/key/folder");
	keySetName (check, "user/notsame/folder");
	succeed_if (keyRel (key, check) < -2, "key is not below");

	keySetName (key, "user/key/folder");
	keySetName (check, "system/notsame/folder");
	succeed_if (keyRel (key, check) == -2, "not in the same namespace");

	keyDel (key);
	keyDel (check);
}

static void test_hierarchy()
{
	printf ("check hierarchy\n");
	Key *key = keyNew(0);
	Key *check = keyNew(0);

	keySetName (key, "user/key/folder/key");
	keySetName (check, "user/other/folder/key");
	succeed_if (keyRel (key, check) < -2, "should be same");

	keySetName (key, "system/key/folder/key");
	keySetName (check, "system/other/folder/key");
	succeed_if (keyRel (key, check) < -2, "should be same");

	keySetName (key, "user/key/folder/key");
	keySetName (check, "system/other/folder/key");
	succeed_if (keyRel (key, check) == -2, "should be different");

	keySetName (key, "system/key/folder/key");
	keySetName (check, "user/other/folder/key");
	succeed_if (keyRel (key, check) == -2, "should be different");

	keyDel (key);
	keyDel (check);
}

static void test_null()
{
	printf ("check invalid keys or null ptr\n");
	Key *key = keyNew(0);
	Key *check = keyNew(0);

	succeed_if (keyRel (key, check) == -1, "invalid");

	succeed_if (keyRel (0, check) == -1, "null ptr");

	succeed_if (keyRel (key, 0) == -1, "null ptr");

	keySetName (check, "system/key/folder/key");
	succeed_if (keyRel (key, check) == -1, "should be still invalid");

	keyDel (key);
	keyDel (check);
}



int main(int argc, char** argv)
{
	printf("KEY RELATION TESTS\n");
	printf("==================\n\n");

	init (argc, argv);

	test_equal();
	test_directbelow();
	test_below();
	test_examples();
	test_hierarchy();
	test_null();

	printf("\ntest_key RESULTS: %d test(s) done. %d error(s).\n", nbTest, nbError);

	return nbError;
}
