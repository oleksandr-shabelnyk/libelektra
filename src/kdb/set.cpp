#include <set.hpp>

#include <kdb.hpp>
#include <cmdline.hpp>
#include <print.hpp>

#include <iostream>

using namespace std;
using namespace kdb;

SetCommand::SetCommand()
{}

int SetCommand::execute(Cmdline const& cl)
{
	int argc = cl.arguments.size();
	if (argc != 1 && argc != 2)
	{
		throw invalid_argument("1 or 2 arguments needed");
	}

	std::string name = cl.arguments[0];

	bool nullValue;
	std::string value;

	if (argc == 2)
	{
		nullValue = false;
		value = cl.arguments[1];
	}
	else
	{
		nullValue = true;
	}

	KeySet conf;
	Key k(name, KEY_END);

	// do not resume on any get errors
	// otherwise the user might break
	// the config
	kdb.get(conf, k);

	Key key = conf.lookup(name);
	if (cl.verbose)
	{
		cout << "Getting configuration emitted warnings:" << endl;
		printWarnings(k);
	}

	if (!key)
	{
		cout << "create a new key " << name;
		key = Key(name, KEY_END);
		if (!nullValue)
		{
			cout << " with string " << value << endl;
			key.setString(value);
		} else {
			cout << " with null value" << endl;
			key.setBinary(0, 0);
		}
		if (!key.isValid())
		{
			cerr << "no valid name supplied" << endl;
			return 1;
		}
		conf.append(key);
	} else {
		if (!nullValue)
		{
			cout << "Set string to " << value << endl;
			key.setString(value);
		} else {
			cout << "Set null value" << endl;
			key.setBinary(0, 0);
		}
	}
	Key n;
	kdb.set(conf, n);

	printWarnings(n);

	return 0;
}

SetCommand::~SetCommand()
{}
