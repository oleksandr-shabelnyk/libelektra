/**
 * @file
 *
 * @brief
 *
 * @copyright BSD License (see doc/COPYING or http://www.libelektra.org)
 */

%module kdb

%feature("autodoc", "3");

%include "attribute.i"
%include "std_string.i"
%include "stdint.i"
%include "exception.i"
%include "std_except.i"

/* add mapping for std::bad_alloc exception */
namespace std {
  %std_exception_map(bad_alloc, SWIG_MemoryError);
}


%{
  extern "C" {
    #include "kdbconfig.h"
    #include "kdbprivate.h" /* required for KEYSET_SIZE */
    #include "kdb.h"
  }

  #include "keyexcept.hpp"
  #include "kdbexcept.hpp"
  #include "key.hpp"
  #include "keyset.hpp"
  #include "kdb.hpp"
  using namespace kdb;
%}

%apply long { ssize_t }

/****************************************************************************
 *
 * kdb.h
 *
 ****************************************************************************/
%constant void *KS_END = KS_END;
%constant const char *VERSION = KDB_VERSION;
%constant const short VERSION_MAJOR = KDB_VERSION_MAJOR;
%constant const short VERSION_MINOR = KDB_VERSION_MINOR;
%constant const short VERSION_MICRO = KDB_VERSION_MICRO;
/* we only care about the enums. ignore the c functions */
%ignore ckdb;
%include "kdb.h"



/****************************************************************************
 *
 * kdb::Key
 *
 ****************************************************************************/

/* 
 * Exceptions 
 */
%exceptionclass kdb::Exception;
%rename("to_s") kdb::Exception::what;

%exceptionclass kdb::KeyInvalidName;
%exceptionclass kdb::KeyException;
%exceptionclass kdb::KeyNotFoundException;
%exceptionclass kdb::KeyTypeException;
%exceptionclass kdb::KeyTypeConversion;

%include "keyexcept.hpp"

/* define which methods are throwing which exceptions */
%catches (kdb::KeyException) kdb::Key::getName;
%catches (kdb::KeyException) kdb::Key::getFullName;

%catches (kdb::KeyInvalidName) kdb::Key::setName;
%catches (kdb::KeyInvalidName) kdb::Key::addName;
%catches (kdb::KeyInvalidName) kdb::Key::setBaseName;
%catches (kdb::KeyInvalidName) kdb::Key::addBaseName;

%catches (kdb::KeyTypeMismatch, kdb::KeyException) kdb::Key::getString;
%catches (kdb::KeyTypeMismatch, kdb::KeyException) kdb::Key::getBinary;

%catches (std::bad_alloc) kdb::Key::Key;


/* ignore certain methods */
//%ignore kdb::Key::Key ();
//%ignore kdb::Key::Key (const std::string keyName, ...);
//%ignore kdb::Key::Key (const char *keyName, va_list ap);
%ignore kdb::Key::Key (char const *keyName, ...);
%ignore kdb::Key::Key (ckdb::Key *k);
%ignore kdb::Key::Key (Key &k);
%ignore kdb::Key::Key (Key const &k);

%ignore kdb::Key::operator++;
%ignore kdb::Key::operator--;
%ignore kdb::Key::operator=;
%ignore kdb::Key::operator->;
%ignore kdb::Key::operator bool;

/* This seems to be implemented in ruby by '! ==' */
%ignore kdb::Key::operator!=;

/* we do not need the raw key */
%ignore kdb::Key::getKey;
%ignore kdb::Key::operator*;
%ignore kdb::Key::release;

/* we do not need the string sizes functions, since the give wrong
 * (size + 1) size info */
%ignore kdb::Key::getNameSize;
%ignore kdb::Key::getBaseNameSize;
%ignore kdb::Key::getFullNameSize;
%ignore kdb::Key::getStringSize;
/* kdb::Key::getBinarySize could be useful */


/* predicate methods rename to "is_xxx?" and return Rubys boolean */
%predicate kdb::Key::isValid;
%predicate kdb::Key::isSystem;
%predicate kdb::Key::isUser;
%predicate kdb::Key::isString;
%predicate kdb::Key::isBinary;
%predicate kdb::Key::isInactive;
%predicate kdb::Key::isBelow;
%predicate kdb::Key::isBelowOrSame;
%predicate kdb::Key::isDirectBelow;
%predicate kdb::Key::hasMeta;
%predicate kdb::Key::isNull; // TODO: do we need something special here??? 
%predicate kdb::Key::needSync;

/* rename some methods to meet the Ruby naming conventions */
%rename("name") kdb::Key::getName;
%rename("name=") kdb::Key::setName;

%rename("base_name") kdb::Key::getBaseName;
%rename("base_name=") kdb::Key::setBaseName;

%rename("full_name") kdb::Key::getFullName;

%rename("namespace") kdb::Key::getNamespace;


/* autorename and templates has some problems */
%rename("get") kdb::Key::get<std::string>;
%rename("set") kdb::Key::set<std::string>;
%alias kdb::Key::get<std::string> "value"
%alias kdb::Key::set<std::string> "value="

%rename("set_meta") kdb::Key::setMeta<std::string>;
%rename("get_meta") kdb::Key::getMeta<std::string>;

%alias kdb::Key::setMeta<std::string> "[]="
%alias kdb::Key::getMeta<std::string> "[]"

/* getMeta Typemap
 * This is used to convert the input argument to a Ruby string. In certain
 * cases this is useful, to allow passing in Symbols as meta names. */
%typemap(in) (const std::string & metaName) {
  // typemap in for getMeta
  $input = rb_funcall($input, rb_intern("to_s"), 0, NULL);
  $1 = new std::string(StringValueCStr($input));
}
%typemap(freearg) (const std::string & metaName) {
  // typemap in for getMeta
  delete $1;
}

/* Typemap for setBinary
 * pass raw data pointer of a Ruby String and its length */
%typemap(in) (const void * newBinary, size_t dataSize) {
  $1 = (void *) StringValuePtr($input);
  $2 = RSTRING_LEN($input);
}


/* 'imitate' va_list as Ruby Hash
 * 
 * "missuse" the exception feature of SWIG to provide a custom
 *  method invocation. This allows us to pass a Ruby argument hash
 *  as a va_list. This way, we can imitate the variable argument
 *  list (and keyword argument) features
 */
%typemap(in) (va_list ap) {
  // we expect to be $input to be a Ruby Hash
  Check_Type($input, T_HASH);
}

%feature("except") kdb::Key::Key (const char *keyName, va_list ap) {
  /* standard method invocation would be: 
  $action
  */
  /* exception features do not have local variables,
     so we define them our selfs */
  int hash_size = 0;
  VALUE keys_arr;
  VALUE key;
  VALUE val;
  int i;
  int flags = 0;

  /* $input substitution does not here, so we have to reverence
     input variables directly */

  hash_size = NUM2INT(rb_funcall(argv[1], rb_intern("size"), 0, NULL));
  keys_arr = rb_funcall(argv[1], rb_intern("keys"), 0, NULL);
  if (hash_size > 0) {
    /* first we check if we can find the "flags" key.
       this has to be passed to the kdb::Key constructor already */
    for (i = 0; i < hash_size; i++) {
      key = rb_ary_entry(keys_arr, i);
      val = rb_hash_aref(argv[1], key);
      /* convert key to String, in case of being a Symbol */
      key = rb_funcall(key, rb_intern("to_s"), 0, NULL);
      /* check for flags and extract them */
      if (strcmp("flags", StringValueCStr(key)) == 0) {
        Check_Type(val, T_FIXNUM);
        flags = NUM2INT(val);
        //printf("got flags: %d\n", flags);
      }
    }
  }
  /* invoke method
     since we can't use arg2 here (is of type va_list)
     we have to do it ourself (not very portable)
  */
  try {
    result = (kdb::Key *)new kdb::Key((char const *)arg1, 
      KEY_FLAGS, flags,
      KEY_END);
  } catch (std::bad_alloc &_e) {
    SWIG_exception_fail(SWIG_MemoryError, (&_e)->what());
  }
  DATA_PTR(self) = result;
  
  if (hash_size > 0) {
    /* now treat (nearly) all key-value pairs as meta data, thus
       assign it to the newly created kdb::Key object */
    for (i = 0; i < hash_size; i++) {
      key = rb_ary_entry(keys_arr, i);
      val = rb_hash_aref(argv[1], key);
      key = rb_funcall(key, rb_intern("to_s"), 0, NULL);
      val = rb_funcall(val, rb_intern("to_s"), 0, NULL);
      /* ignore certain keys */
      if (strcmp("flags", StringValueCStr(key)) == 0) continue;
      /* 'value' has also a special meening */
      if (strcmp("value", StringValueCStr(key)) == 0) {
        if (flags & KEY_BINARY) {
          result->setBinary(StringValuePtr(val), RSTRING_LEN(val));
        } else {
          result->setString(StringValueCStr(val));
        }
      } else {
        result->setMeta(StringValueCStr(key), StringValueCStr(val));
      }
    }
  }
  
}


/* universal 'get' and 'set' (value) methods
 *
 * This allows the univeral use of get/set methods, while really
 * calling get|setBinary|String depending on the current Key
 * type */
%feature("except") kdb::Key::get<std::string> {
  // redefine our Key::get 
  /*
  $action
  */
  if (((kdb::Key const *)arg1)->isBinary()) {
    result = ((kdb::Key const *)arg1)->getBinary();
  } else {
    result = ((kdb::Key const *)arg1)->getString();
  }
}

%feature("except") kdb::Key::set<std::string> {
  // redefine our Key::set 
  /*
  $action
  */
  if (((kdb::Key const *)arg1)->isBinary()) {
    arg1->setBinary(StringValuePtr(argv[0]),
                RSTRING_LEN(argv[0]));
  } else {
    arg1->setString(StringValueCStr(argv[0]));
  }
}


/* 
 * Iterators
 */
// exclude them for now
#define ELEKTRA_WITHOUT_ITERATOR

/* 
 * Key clonging
 */
%ignore kdb::Key::dup;
%ignore kdb::Key::copy;

%alias kdb::Key::clone() "dup"

%extend kdb::Key {
  kdb::Key *clone() {
    kdb::Key *k;
    k = new kdb::Key();
    k->copy(*$self);
    return k;
  }
}


/*
 * Key callback methods
 * (ignore them for now, TODO: implement this stuff
 */
%ignore kdb::Key::setCallback;
%ignore kdb::Key::getFunc;

/*
 * spaceship operator, useful for sorting methods
 */
//%rename("<=>") kdb::Key::spaceship;
%alias kdb::Key::spaceship "<=>"
%extend kdb::Key {
  int spaceship(const kdb::Key &comp) {
    int ret = ckdb::keyCmp ($self->getKey(), comp.getKey());
    if (ret < 0) return -1;
    if (ret > 0) return 1;
    return 0;
  }
}
 

/*
 * parse key.hpp
 */
%include "key.hpp"


/* 
 * used Templates
 */
/* value methods */
%template("get") kdb::Key::get<std::string>;
%template("set") kdb::Key::set<std::string>;

/* meta data */
//%template(getMeta) kdb::Key::getMeta<const kdb::Key>;
%template("set_meta") kdb::Key::setMeta<std::string>;
%template("get_meta") kdb::Key::getMeta<std::string>;




/****************************************************************************
 *
 * kdb::KeySet
 *
 ****************************************************************************/

/* ignore unused constructors */
%ignore kdb::KeySet::KeySet (ckdb::KeySet * k);
%ignore kdb::KeySet::KeySet (size_t alloc, ...);
%ignore kdb::KeySet::KeySet (VaAlloc alloc, va_list ap);

%ignore kdb::VaAlloc;


/* ignore raw ckdb::KeySet methods */
%ignore kdb::KeySet::getKeySet;
%ignore kdb::KeySet::setKeySet;
%ignore kdb::KeySet::release;

/* ignore unused operators */
%ignore kdb::KeySet::operator=;
/* KeySet == operator see below */
%ignore kdb::operator== (const KeySet &, const KeySet &);
%ignore kdb::operator!= (const KeySet &, const KeySet &);


/*
 * Constructors
 */

/* special mapping for KeySet::KeySet(Key, ...) constructor
 * to enable passing a single Key, or an Array of Keys.
 * This allows KeySet creation in a more Ruby way */
/* first check if we've got a Key or a Ruby-array */
%typemap(in) (kdb::Key, ...) {
  $2 = NULL;
  if (!RB_TYPE_P($input, T_ARRAY)){
    if (SWIG_ConvertPtr($input, (void**)&$2, SWIGTYPE_p_kdb__Key, 0) == -1) {
      rb_raise(rb_eArgError, "Argument has to be of Type Kdb::Key or Array");
      SWIG_fail;
    }
  }
}
/* define a custom KeySet creation to be able to append the given Key 
 * arguments to the newly created KeySet */
%feature("except") kdb::KeySet::KeySet (Key, ...) {
  /* original action
  $action
  */

  if (arg2 != NULL) {
    /* we got a kdb::Key argument (see corresponding typemap) */
    kdb::Key *k = (kdb::Key *)arg2;
    result = (kdb::KeySet *)new kdb::KeySet();
    result->append(*k);
  } else {
    /* Ruby-Array */
    if (RARRAY_LEN(argv[0]) > KEYSET_SIZE) {
      /* if we know that the Array is bigger than the default KeySet size
         create a KeySet which is able to hold all elements without 
         reallocation */
      result = (kdb::KeySet *)new kdb::KeySet(RARRAY_LEN(argv[0]), KS_END);
    } else {
      result = (kdb::KeySet *)new kdb::KeySet();
    }
    /* append each array element, while checking if we really got a Key */
    for (int i = 0; i < RARRAY_LEN(argv[0]); i++) {
      VALUE e;
      kdb::Key *ek = NULL;
      e = rb_ary_entry(argv[0], i);
      if (SWIG_ConvertPtr(e, (void**)&ek, SWIGTYPE_p_kdb__Key, 0) == -1) {
        rb_raise(rb_eArgError, 
            "Array element at index %d is not of Type Kdb::Key", i);
        delete result;
        SWIG_fail;
      }
      result->append(*ek);
    }
  }
  DATA_PTR(self) = result;
}



/* 
 * be more Ruby native: 
 * for all methods, which return a Key, for which Key.is_null? returns true
 * (null-key), return NIL instead */
namespace kdb {
  class KeySet;

  %typemap(out) Key {
    if ($1.isNull()) {
      $result = Qnil;
    } else {
      $result = SWIG_NewPointerObj(new kdb::Key($1), 
                                    SWIGTYPE_p_kdb__Key, 
                                    SWIG_POINTER_OWN | 0);
    }
  }
}


/* 
 * KeySet.each
 * Hint: this implementation of 'each' only works wich references to keys
 * so any modifications of the keys are persisted
 */
%extend kdb::KeySet {
  void each() {
    if (rb_block_given_p()) {
      cursor_t cur_pos = $self->getCursor();

      for ( $self->rewind(); $self->next(); ) {
        VALUE cur;
        Key * t = new Key($self->current());
        cur = SWIG_NewPointerObj(t, SWIGTYPE_p_kdb__Key, 1);

        rb_yield(cur);

        /* TODO: do we have to free anything ? */
      }
      /* restore current cursor position */
      $self->setCursor(cur_pos);
    }
  }
}
/* include Enumerable which adds lots of Ruby iter., search... functions */
%mixin kdb::KeySet "Enumerable";


/* 
 * append methods 
 */
%alias kdb::KeySet::append "<<"

/* define special typemap for append(KeySet), to allow
 * passing a Ruby-Array also (a little bit hacky) */
%typemap(in) (const kdb::KeySet & toAppend) {
  /* in case we have an array, append each element and return */
  if (RB_TYPE_P($input, T_ARRAY)) {
    int size = RARRAY_LEN($input);
    //fprintf(stderr,"append Array of Keys of len %d\n", size);
    for ( int i = 0; i < size; ++i) {
      Key* k;
      int reskey = 0;
      reskey = SWIG_ConvertPtr(
          rb_ary_entry($input, i), (void**)&k, SWIGTYPE_p_kdb__Key, 0);
      if (!SWIG_IsOK(reskey)) {
        rb_raise(rb_eArgError, 
            "Array element at index %d is not of Type Kdb::Key", i);
        SWIG_fail;
      }
      arg1->append(*k);
    }
    return 0;
    
  } else {
  /* standard case for KeySet, just convert and check for correct type */
    //fprintf(stderr, "append KeySet\n");
    if (!SWIG_IsOK(
          SWIG_ConvertPtr($input, (void**)&$1, SWIGTYPE_p_kdb__KeySet, 0))) {
      rb_raise(rb_eArgError,
          "Argument not of Type Kdb::KeySet");
      SWIG_fail;
    }
  }
}


/* 
 * cursor operations 
 */
%apply long { cursor_t }
%rename("cursor") kdb::KeySet::getCursor;
%rename("cursor=") kdb::KeySet::setCursor;

%alias kdb::KeySet::at "[]"


/*
 * comparision operator
 * this is required, since operator== is not part of KeySet, thus
 * SWIG doesn't add this to class KeySet
 * (otherwise 'kdb::== ks1, ks2' would be required)
 */
%alias kdb::KeySet::operator== "eql?"
%extend kdb::KeySet {
  bool operator== (const KeySet & rhs) {
    return *$self == rhs;
  }
}


/*
 * lookup
 */
%apply int { option_t }



/*
 * dup, copy, clone
 * shallow copy KeySet
 */

/* return a kdb::KeySet instead of a ckdb::KeySet */
%typemap(out) ckdb::KeySet* kdb::KeySet::dup {
  $result = SWIG_NewPointerObj(new KeySet($1), 
                                SWIGTYPE_p_kdb__KeySet,
                                SWIG_POINTER_OWN | 0);
}

%alias kdb::KeySet::dup "clone"


/*
 * handy helper methods or common aliases
 */
%rename("empty?") kdb::KeySet::empty;
%extend kdb::KeySet {
  bool empty () {
    return $self->size() == 0;
  }
}

%alias kdb::KeySet::size "length"

/* 
 * parse keyset.hpp
 */
%include "keyset.hpp"



/****************************************************************************
 *
 * kdb.hpp
 *
 ****************************************************************************/

%include "kdb.hpp"
