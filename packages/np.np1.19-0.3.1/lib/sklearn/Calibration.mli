(** Get an attribute of this module as a Py.Object.t.
                   This is useful to pass a Python function to another function. *)
val get_py : string -> Py.Object.t

module CalibratedClassifierCV : sig
type tag = [`CalibratedClassifierCV]
type t = [`BaseEstimator | `CalibratedClassifierCV | `ClassifierMixin | `MetaEstimatorMixin | `Object] Obj.t
val of_pyobject : Py.Object.t -> t
val to_pyobject : [> tag] Obj.t -> Py.Object.t

val as_estimator : t -> [`BaseEstimator] Obj.t
val as_meta_estimator : t -> [`MetaEstimatorMixin] Obj.t
val as_classifier : t -> [`ClassifierMixin] Obj.t
val create : ?base_estimator:[>`BaseEstimator] Np.Obj.t -> ?method_:[`Sigmoid | `Isotonic] -> ?cv:[`BaseCrossValidator of [>`BaseCrossValidator] Np.Obj.t | `Prefit | `Arr of [>`ArrayLike] Np.Obj.t | `I of int] -> unit -> t
(**
Probability calibration with isotonic regression or logistic regression.

The calibration is based on the :term:`decision_function` method of the
`base_estimator` if it exists, else on :term:`predict_proba`.

Read more in the :ref:`User Guide <calibration>`.

Parameters
----------
base_estimator : instance BaseEstimator
    The classifier whose output need to be calibrated to provide more
    accurate `predict_proba` outputs.

method : 'sigmoid' or 'isotonic'
    The method to use for calibration. Can be 'sigmoid' which
    corresponds to Platt's method (i.e. a logistic regression model) or
    'isotonic' which is a non-parametric approach. It is not advised to
    use isotonic calibration with too few calibration samples
    ``(<<1000)`` since it tends to overfit.

cv : integer, cross-validation generator, iterable or 'prefit', optional
    Determines the cross-validation splitting strategy.
    Possible inputs for cv are:

    - None, to use the default 5-fold cross-validation,
    - integer, to specify the number of folds.
    - :term:`CV splitter`,
    - An iterable yielding (train, test) splits as arrays of indices.

    For integer/None inputs, if ``y`` is binary or multiclass,
    :class:`sklearn.model_selection.StratifiedKFold` is used. If ``y`` is
    neither binary nor multiclass, :class:`sklearn.model_selection.KFold`
    is used.

    Refer :ref:`User Guide <cross_validation>` for the various
    cross-validation strategies that can be used here.

    If 'prefit' is passed, it is assumed that `base_estimator` has been
    fitted already and all data is used for calibration.

    .. versionchanged:: 0.22
        ``cv`` default value if None changed from 3-fold to 5-fold.

Attributes
----------
classes_ : array, shape (n_classes)
    The class labels.

calibrated_classifiers_ : list (len() equal to cv or 1 if cv == 'prefit')
    The list of calibrated classifiers, one for each cross-validation fold,
    which has been fitted on all but the validation fold and calibrated
    on the validation fold.

References
----------
.. [1] Obtaining calibrated probability estimates from decision trees
       and naive Bayesian classifiers, B. Zadrozny & C. Elkan, ICML 2001

.. [2] Transforming Classifier Scores into Accurate Multiclass
       Probability Estimates, B. Zadrozny & C. Elkan, (KDD 2002)

.. [3] Probabilistic Outputs for Support Vector Machines and Comparisons to
       Regularized Likelihood Methods, J. Platt, (1999)

.. [4] Predicting Good Probabilities with Supervised Learning,
       A. Niculescu-Mizil & R. Caruana, ICML 2005
*)

val fit : ?sample_weight:[>`ArrayLike] Np.Obj.t -> x:[>`ArrayLike] Np.Obj.t -> y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> t
(**
Fit the calibrated model

Parameters
----------
X : array-like, shape (n_samples, n_features)
    Training data.

y : array-like, shape (n_samples,)
    Target values.

sample_weight : array-like of shape (n_samples,), default=None
    Sample weights. If None, then samples are equally weighted.

Returns
-------
self : object
    Returns an instance of self.
*)

val get_params : ?deep:bool -> [> tag] Obj.t -> Dict.t
(**
Get parameters for this estimator.

Parameters
----------
deep : bool, default=True
    If True, will return the parameters for this estimator and
    contained subobjects that are estimators.

Returns
-------
params : mapping of string to any
    Parameter names mapped to their values.
*)

val predict : x:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Predict the target of new samples. The predicted class is the
class that has the highest probability, and can thus be different
from the prediction of the uncalibrated classifier.

Parameters
----------
X : array-like, shape (n_samples, n_features)
    The samples.

Returns
-------
C : array, shape (n_samples,)
    The predicted class.
*)

val predict_proba : x:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Posterior probabilities of classification

This function returns posterior probabilities of classification
according to each class on an array of test vectors X.

Parameters
----------
X : array-like, shape (n_samples, n_features)
    The samples.

Returns
-------
C : array, shape (n_samples, n_classes)
    The predicted probas.
*)

val score : ?sample_weight:[>`ArrayLike] Np.Obj.t -> x:[>`ArrayLike] Np.Obj.t -> y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> float
(**
Return the mean accuracy on the given test data and labels.

In multi-label classification, this is the subset accuracy
which is a harsh metric since you require for each sample that
each label set be correctly predicted.

Parameters
----------
X : array-like of shape (n_samples, n_features)
    Test samples.

y : array-like of shape (n_samples,) or (n_samples, n_outputs)
    True labels for X.

sample_weight : array-like of shape (n_samples,), default=None
    Sample weights.

Returns
-------
score : float
    Mean accuracy of self.predict(X) wrt. y.
*)

val set_params : ?params:(string * Py.Object.t) list -> [> tag] Obj.t -> t
(**
Set the parameters of this estimator.

The method works on simple estimators as well as on nested objects
(such as pipelines). The latter have parameters of the form
``<component>__<parameter>`` so that it's possible to update each
component of a nested object.

Parameters
----------
**params : dict
    Estimator parameters.

Returns
-------
self : object
    Estimator instance.
*)


(** Attribute classes_: get value or raise Not_found if None.*)
val classes_ : t -> [>`ArrayLike] Np.Obj.t

(** Attribute classes_: get value as an option. *)
val classes_opt : t -> ([>`ArrayLike] Np.Obj.t) option


(** Attribute calibrated_classifiers_: get value or raise Not_found if None.*)
val calibrated_classifiers_ : t -> [>`ArrayLike] Np.Obj.t

(** Attribute calibrated_classifiers_: get value as an option. *)
val calibrated_classifiers_opt : t -> ([>`ArrayLike] Np.Obj.t) option


(** Print the object to a human-readable representation. *)
val to_string : t -> string


(** Print the object to a human-readable representation. *)
val show : t -> string

(** Pretty-print the object to a formatter. *)
val pp : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]


end

module IsotonicRegression : sig
type tag = [`IsotonicRegression]
type t = [`BaseEstimator | `IsotonicRegression | `Object | `RegressorMixin | `TransformerMixin] Obj.t
val of_pyobject : Py.Object.t -> t
val to_pyobject : [> tag] Obj.t -> Py.Object.t

val as_transformer : t -> [`TransformerMixin] Obj.t
val as_estimator : t -> [`BaseEstimator] Obj.t
val as_regressor : t -> [`RegressorMixin] Obj.t
val create : ?y_min:float -> ?y_max:float -> ?increasing:[`Auto | `Bool of bool] -> ?out_of_bounds:string -> unit -> t
(**
Isotonic regression model.

Read more in the :ref:`User Guide <isotonic>`.

.. versionadded:: 0.13

Parameters
----------
y_min : float, default=None
    Lower bound on the lowest predicted value (the minimum value may
    still be higher). If not set, defaults to -inf.

y_max : float, default=None
    Upper bound on the highest predicted value (the maximum may still be
    lower). If not set, defaults to +inf.

increasing : bool or 'auto', default=True
    Determines whether the predictions should be constrained to increase
    or decrease with `X`. 'auto' will decide based on the Spearman
    correlation estimate's sign.

out_of_bounds : str, default='nan'
    The ``out_of_bounds`` parameter handles how `X` values outside of the
    training domain are handled.  When set to 'nan', predictions
    will be NaN.  When set to 'clip', predictions will be
    set to the value corresponding to the nearest train interval endpoint.
    When set to 'raise' a `ValueError` is raised.


Attributes
----------
X_min_ : float
    Minimum value of input array `X_` for left bound.

X_max_ : float
    Maximum value of input array `X_` for right bound.

f_ : function
    The stepwise interpolating function that covers the input domain ``X``.

increasing_ : bool
    Inferred value for ``increasing``.

Notes
-----
Ties are broken using the secondary method from Leeuw, 1977.

References
----------
Isotonic Median Regression: A Linear Programming Approach
Nilotpal Chakravarti
Mathematics of Operations Research
Vol. 14, No. 2 (May, 1989), pp. 303-308

Isotone Optimization in R : Pool-Adjacent-Violators
Algorithm (PAVA) and Active Set Methods
Leeuw, Hornik, Mair
Journal of Statistical Software 2009

Correctness of Kruskal's algorithms for monotone regression with ties
Leeuw, Psychometrica, 1977

Examples
--------
>>> from sklearn.datasets import make_regression
>>> from sklearn.isotonic import IsotonicRegression
>>> X, y = make_regression(n_samples=10, n_features=1, random_state=41)
>>> iso_reg = IsotonicRegression().fit(X.flatten(), y)
>>> iso_reg.predict([.1, .2])
array([1.8628..., 3.7256...])
*)

val fit : ?sample_weight:[>`ArrayLike] Np.Obj.t -> x:[>`ArrayLike] Np.Obj.t -> y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> t
(**
Fit the model using X, y as training data.

Parameters
----------
X : array-like of shape (n_samples,)
    Training data.

y : array-like of shape (n_samples,)
    Training target.

sample_weight : array-like of shape (n_samples,), default=None
    Weights. If set to None, all weights will be set to 1 (equal
    weights).

Returns
-------
self : object
    Returns an instance of self.

Notes
-----
X is stored for future use, as :meth:`transform` needs X to interpolate
new input data.
*)

val fit_transform : ?y:[>`ArrayLike] Np.Obj.t -> ?fit_params:(string * Py.Object.t) list -> x:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Fit to data, then transform it.

Fits transformer to X and y with optional parameters fit_params
and returns a transformed version of X.

Parameters
----------
X : {array-like, sparse matrix, dataframe} of shape                 (n_samples, n_features)

y : ndarray of shape (n_samples,), default=None
    Target values.

**fit_params : dict
    Additional fit parameters.

Returns
-------
X_new : ndarray array of shape (n_samples, n_features_new)
    Transformed array.
*)

val get_params : ?deep:bool -> [> tag] Obj.t -> Dict.t
(**
Get parameters for this estimator.

Parameters
----------
deep : bool, default=True
    If True, will return the parameters for this estimator and
    contained subobjects that are estimators.

Returns
-------
params : mapping of string to any
    Parameter names mapped to their values.
*)

val predict : t:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Predict new data by linear interpolation.

Parameters
----------
T : array-like of shape (n_samples,)
    Data to transform.

Returns
-------
y_pred : ndarray of shape (n_samples,)
    Transformed data.
*)

val score : ?sample_weight:[>`ArrayLike] Np.Obj.t -> x:[>`ArrayLike] Np.Obj.t -> y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> float
(**
Return the coefficient of determination R^2 of the prediction.

The coefficient R^2 is defined as (1 - u/v), where u is the residual
sum of squares ((y_true - y_pred) ** 2).sum() and v is the total
sum of squares ((y_true - y_true.mean()) ** 2).sum().
The best possible score is 1.0 and it can be negative (because the
model can be arbitrarily worse). A constant model that always
predicts the expected value of y, disregarding the input features,
would get a R^2 score of 0.0.

Parameters
----------
X : array-like of shape (n_samples, n_features)
    Test samples. For some estimators this may be a
    precomputed kernel matrix or a list of generic objects instead,
    shape = (n_samples, n_samples_fitted),
    where n_samples_fitted is the number of
    samples used in the fitting for the estimator.

y : array-like of shape (n_samples,) or (n_samples, n_outputs)
    True values for X.

sample_weight : array-like of shape (n_samples,), default=None
    Sample weights.

Returns
-------
score : float
    R^2 of self.predict(X) wrt. y.

Notes
-----
The R2 score used when calling ``score`` on a regressor uses
``multioutput='uniform_average'`` from version 0.23 to keep consistent
with default value of :func:`~sklearn.metrics.r2_score`.
This influences the ``score`` method of all the multioutput
regressors (except for
:class:`~sklearn.multioutput.MultiOutputRegressor`).
*)

val set_params : ?params:(string * Py.Object.t) list -> [> tag] Obj.t -> t
(**
Set the parameters of this estimator.

The method works on simple estimators as well as on nested objects
(such as pipelines). The latter have parameters of the form
``<component>__<parameter>`` so that it's possible to update each
component of a nested object.

Parameters
----------
**params : dict
    Estimator parameters.

Returns
-------
self : object
    Estimator instance.
*)

val transform : t:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Transform new data by linear interpolation

Parameters
----------
T : array-like of shape (n_samples,)
    Data to transform.

Returns
-------
y_pred : ndarray of shape (n_samples,)
    The transformed data
*)


(** Attribute X_min_: get value or raise Not_found if None.*)
val x_min_ : t -> float

(** Attribute X_min_: get value as an option. *)
val x_min_opt : t -> (float) option


(** Attribute X_max_: get value or raise Not_found if None.*)
val x_max_ : t -> float

(** Attribute X_max_: get value as an option. *)
val x_max_opt : t -> (float) option


(** Attribute f_: get value or raise Not_found if None.*)
val f_ : t -> Py.Object.t

(** Attribute f_: get value as an option. *)
val f_opt : t -> (Py.Object.t) option


(** Attribute increasing_: get value or raise Not_found if None.*)
val increasing_ : t -> bool

(** Attribute increasing_: get value as an option. *)
val increasing_opt : t -> (bool) option


(** Print the object to a human-readable representation. *)
val to_string : t -> string


(** Print the object to a human-readable representation. *)
val show : t -> string

(** Pretty-print the object to a formatter. *)
val pp : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]


end

module LabelBinarizer : sig
type tag = [`LabelBinarizer]
type t = [`BaseEstimator | `LabelBinarizer | `Object | `TransformerMixin] Obj.t
val of_pyobject : Py.Object.t -> t
val to_pyobject : [> tag] Obj.t -> Py.Object.t

val as_transformer : t -> [`TransformerMixin] Obj.t
val as_estimator : t -> [`BaseEstimator] Obj.t
val create : ?neg_label:int -> ?pos_label:int -> ?sparse_output:bool -> unit -> t
(**
Binarize labels in a one-vs-all fashion

Several regression and binary classification algorithms are
available in scikit-learn. A simple way to extend these algorithms
to the multi-class classification case is to use the so-called
one-vs-all scheme.

At learning time, this simply consists in learning one regressor
or binary classifier per class. In doing so, one needs to convert
multi-class labels to binary labels (belong or does not belong
to the class). LabelBinarizer makes this process easy with the
transform method.

At prediction time, one assigns the class for which the corresponding
model gave the greatest confidence. LabelBinarizer makes this easy
with the inverse_transform method.

Read more in the :ref:`User Guide <preprocessing_targets>`.

Parameters
----------

neg_label : int (default: 0)
    Value with which negative labels must be encoded.

pos_label : int (default: 1)
    Value with which positive labels must be encoded.

sparse_output : boolean (default: False)
    True if the returned array from transform is desired to be in sparse
    CSR format.

Attributes
----------

classes_ : array of shape [n_class]
    Holds the label for each class.

y_type_ : str,
    Represents the type of the target data as evaluated by
    utils.multiclass.type_of_target. Possible type are 'continuous',
    'continuous-multioutput', 'binary', 'multiclass',
    'multiclass-multioutput', 'multilabel-indicator', and 'unknown'.

sparse_input_ : boolean,
    True if the input data to transform is given as a sparse matrix, False
    otherwise.

Examples
--------
>>> from sklearn import preprocessing
>>> lb = preprocessing.LabelBinarizer()
>>> lb.fit([1, 2, 6, 4, 2])
LabelBinarizer()
>>> lb.classes_
array([1, 2, 4, 6])
>>> lb.transform([1, 6])
array([[1, 0, 0, 0],
       [0, 0, 0, 1]])

Binary targets transform to a column vector

>>> lb = preprocessing.LabelBinarizer()
>>> lb.fit_transform(['yes', 'no', 'no', 'yes'])
array([[1],
       [0],
       [0],
       [1]])

Passing a 2D matrix for multilabel classification

>>> import numpy as np
>>> lb.fit(np.array([[0, 1, 1], [1, 0, 0]]))
LabelBinarizer()
>>> lb.classes_
array([0, 1, 2])
>>> lb.transform([0, 1, 2, 1])
array([[1, 0, 0],
       [0, 1, 0],
       [0, 0, 1],
       [0, 1, 0]])

See also
--------
label_binarize : function to perform the transform operation of
    LabelBinarizer with fixed classes.
sklearn.preprocessing.OneHotEncoder : encode categorical features
    using a one-hot aka one-of-K scheme.
*)

val fit : y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> t
(**
Fit label binarizer

Parameters
----------
y : array of shape [n_samples,] or [n_samples, n_classes]
    Target values. The 2-d matrix should only contain 0 and 1,
    represents multilabel classification.

Returns
-------
self : returns an instance of self.
*)

val fit_transform : y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Fit label binarizer and transform multi-class labels to binary
labels.

The output of transform is sometimes referred to as
the 1-of-K coding scheme.

Parameters
----------
y : array or sparse matrix of shape [n_samples,] or             [n_samples, n_classes]
    Target values. The 2-d matrix should only contain 0 and 1,
    represents multilabel classification. Sparse matrix can be
    CSR, CSC, COO, DOK, or LIL.

Returns
-------
Y : array or CSR matrix of shape [n_samples, n_classes]
    Shape will be [n_samples, 1] for binary problems.
*)

val get_params : ?deep:bool -> [> tag] Obj.t -> Dict.t
(**
Get parameters for this estimator.

Parameters
----------
deep : bool, default=True
    If True, will return the parameters for this estimator and
    contained subobjects that are estimators.

Returns
-------
params : mapping of string to any
    Parameter names mapped to their values.
*)

val inverse_transform : ?threshold:float -> y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> Py.Object.t
(**
Transform binary labels back to multi-class labels

Parameters
----------
Y : numpy array or sparse matrix with shape [n_samples, n_classes]
    Target values. All sparse matrices are converted to CSR before
    inverse transformation.

threshold : float or None
    Threshold used in the binary and multi-label cases.

    Use 0 when ``Y`` contains the output of decision_function
    (classifier).
    Use 0.5 when ``Y`` contains the output of predict_proba.

    If None, the threshold is assumed to be half way between
    neg_label and pos_label.

Returns
-------
y : numpy array or CSR matrix of shape [n_samples] Target values.

Notes
-----
In the case when the binary labels are fractional
(probabilistic), inverse_transform chooses the class with the
greatest value. Typically, this allows to use the output of a
linear model's decision_function method directly as the input
of inverse_transform.
*)

val set_params : ?params:(string * Py.Object.t) list -> [> tag] Obj.t -> t
(**
Set the parameters of this estimator.

The method works on simple estimators as well as on nested objects
(such as pipelines). The latter have parameters of the form
``<component>__<parameter>`` so that it's possible to update each
component of a nested object.

Parameters
----------
**params : dict
    Estimator parameters.

Returns
-------
self : object
    Estimator instance.
*)

val transform : y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Transform multi-class labels to binary labels

The output of transform is sometimes referred to by some authors as
the 1-of-K coding scheme.

Parameters
----------
y : array or sparse matrix of shape [n_samples,] or             [n_samples, n_classes]
    Target values. The 2-d matrix should only contain 0 and 1,
    represents multilabel classification. Sparse matrix can be
    CSR, CSC, COO, DOK, or LIL.

Returns
-------
Y : numpy array or CSR matrix of shape [n_samples, n_classes]
    Shape will be [n_samples, 1] for binary problems.
*)


(** Attribute classes_: get value or raise Not_found if None.*)
val classes_ : t -> [>`ArrayLike] Np.Obj.t

(** Attribute classes_: get value as an option. *)
val classes_opt : t -> ([>`ArrayLike] Np.Obj.t) option


(** Attribute y_type_: get value or raise Not_found if None.*)
val y_type_ : t -> string

(** Attribute y_type_: get value as an option. *)
val y_type_opt : t -> (string) option


(** Attribute sparse_input_: get value or raise Not_found if None.*)
val sparse_input_ : t -> bool

(** Attribute sparse_input_: get value as an option. *)
val sparse_input_opt : t -> (bool) option


(** Print the object to a human-readable representation. *)
val to_string : t -> string


(** Print the object to a human-readable representation. *)
val show : t -> string

(** Pretty-print the object to a formatter. *)
val pp : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]


end

module LabelEncoder : sig
type tag = [`LabelEncoder]
type t = [`BaseEstimator | `LabelEncoder | `Object | `TransformerMixin] Obj.t
val of_pyobject : Py.Object.t -> t
val to_pyobject : [> tag] Obj.t -> Py.Object.t

val as_transformer : t -> [`TransformerMixin] Obj.t
val as_estimator : t -> [`BaseEstimator] Obj.t
val create : unit -> t
(**
Encode target labels with value between 0 and n_classes-1.

This transformer should be used to encode target values, *i.e.* `y`, and
not the input `X`.

Read more in the :ref:`User Guide <preprocessing_targets>`.

.. versionadded:: 0.12

Attributes
----------
classes_ : array of shape (n_class,)
    Holds the label for each class.

Examples
--------
`LabelEncoder` can be used to normalize labels.

>>> from sklearn import preprocessing
>>> le = preprocessing.LabelEncoder()
>>> le.fit([1, 2, 2, 6])
LabelEncoder()
>>> le.classes_
array([1, 2, 6])
>>> le.transform([1, 1, 2, 6])
array([0, 0, 1, 2]...)
>>> le.inverse_transform([0, 0, 1, 2])
array([1, 1, 2, 6])

It can also be used to transform non-numerical labels (as long as they are
hashable and comparable) to numerical labels.

>>> le = preprocessing.LabelEncoder()
>>> le.fit(['paris', 'paris', 'tokyo', 'amsterdam'])
LabelEncoder()
>>> list(le.classes_)
['amsterdam', 'paris', 'tokyo']
>>> le.transform(['tokyo', 'tokyo', 'paris'])
array([2, 2, 1]...)
>>> list(le.inverse_transform([2, 2, 1]))
['tokyo', 'tokyo', 'paris']

See also
--------
sklearn.preprocessing.OrdinalEncoder : Encode categorical features
    using an ordinal encoding scheme.

sklearn.preprocessing.OneHotEncoder : Encode categorical features
    as a one-hot numeric array.
*)

val fit : y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> t
(**
Fit label encoder

Parameters
----------
y : array-like of shape (n_samples,)
    Target values.

Returns
-------
self : returns an instance of self.
*)

val fit_transform : y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Fit label encoder and return encoded labels

Parameters
----------
y : array-like of shape [n_samples]
    Target values.

Returns
-------
y : array-like of shape [n_samples]
*)

val get_params : ?deep:bool -> [> tag] Obj.t -> Dict.t
(**
Get parameters for this estimator.

Parameters
----------
deep : bool, default=True
    If True, will return the parameters for this estimator and
    contained subobjects that are estimators.

Returns
-------
params : mapping of string to any
    Parameter names mapped to their values.
*)

val inverse_transform : y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Transform labels back to original encoding.

Parameters
----------
y : numpy array of shape [n_samples]
    Target values.

Returns
-------
y : numpy array of shape [n_samples]
*)

val set_params : ?params:(string * Py.Object.t) list -> [> tag] Obj.t -> t
(**
Set the parameters of this estimator.

The method works on simple estimators as well as on nested objects
(such as pipelines). The latter have parameters of the form
``<component>__<parameter>`` so that it's possible to update each
component of a nested object.

Parameters
----------
**params : dict
    Estimator parameters.

Returns
-------
self : object
    Estimator instance.
*)

val transform : y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Transform labels to normalized encoding.

Parameters
----------
y : array-like of shape [n_samples]
    Target values.

Returns
-------
y : array-like of shape [n_samples]
*)


(** Attribute classes_: get value or raise Not_found if None.*)
val classes_ : t -> [>`ArrayLike] Np.Obj.t

(** Attribute classes_: get value as an option. *)
val classes_opt : t -> ([>`ArrayLike] Np.Obj.t) option


(** Print the object to a human-readable representation. *)
val to_string : t -> string


(** Print the object to a human-readable representation. *)
val show : t -> string

(** Pretty-print the object to a formatter. *)
val pp : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]


end

module LinearSVC : sig
type tag = [`LinearSVC]
type t = [`BaseEstimator | `ClassifierMixin | `LinearClassifierMixin | `LinearSVC | `Object | `SparseCoefMixin] Obj.t
val of_pyobject : Py.Object.t -> t
val to_pyobject : [> tag] Obj.t -> Py.Object.t

val as_estimator : t -> [`BaseEstimator] Obj.t
val as_classifier : t -> [`ClassifierMixin] Obj.t
val as_linear_classifier : t -> [`LinearClassifierMixin] Obj.t
val as_sparse_coef : t -> [`SparseCoefMixin] Obj.t
val create : ?penalty:[`L1 | `L2] -> ?loss:[`Hinge | `Squared_hinge] -> ?dual:bool -> ?tol:float -> ?c:float -> ?multi_class:[`Ovr | `Crammer_singer] -> ?fit_intercept:bool -> ?intercept_scaling:float -> ?class_weight:[`Balanced | `DictIntToFloat of (int * float) list] -> ?verbose:int -> ?random_state:int -> ?max_iter:int -> unit -> t
(**
Linear Support Vector Classification.

Similar to SVC with parameter kernel='linear', but implemented in terms of
liblinear rather than libsvm, so it has more flexibility in the choice of
penalties and loss functions and should scale better to large numbers of
samples.

This class supports both dense and sparse input and the multiclass support
is handled according to a one-vs-the-rest scheme.

Read more in the :ref:`User Guide <svm_classification>`.

Parameters
----------
penalty : {'l1', 'l2'}, default='l2'
    Specifies the norm used in the penalization. The 'l2'
    penalty is the standard used in SVC. The 'l1' leads to ``coef_``
    vectors that are sparse.

loss : {'hinge', 'squared_hinge'}, default='squared_hinge'
    Specifies the loss function. 'hinge' is the standard SVM loss
    (used e.g. by the SVC class) while 'squared_hinge' is the
    square of the hinge loss.

dual : bool, default=True
    Select the algorithm to either solve the dual or primal
    optimization problem. Prefer dual=False when n_samples > n_features.

tol : float, default=1e-4
    Tolerance for stopping criteria.

C : float, default=1.0
    Regularization parameter. The strength of the regularization is
    inversely proportional to C. Must be strictly positive.

multi_class : {'ovr', 'crammer_singer'}, default='ovr'
    Determines the multi-class strategy if `y` contains more than
    two classes.
    ``'ovr'`` trains n_classes one-vs-rest classifiers, while
    ``'crammer_singer'`` optimizes a joint objective over all classes.
    While `crammer_singer` is interesting from a theoretical perspective
    as it is consistent, it is seldom used in practice as it rarely leads
    to better accuracy and is more expensive to compute.
    If ``'crammer_singer'`` is chosen, the options loss, penalty and dual
    will be ignored.

fit_intercept : bool, default=True
    Whether to calculate the intercept for this model. If set
    to false, no intercept will be used in calculations
    (i.e. data is expected to be already centered).

intercept_scaling : float, default=1
    When self.fit_intercept is True, instance vector x becomes
    ``[x, self.intercept_scaling]``,
    i.e. a 'synthetic' feature with constant value equals to
    intercept_scaling is appended to the instance vector.
    The intercept becomes intercept_scaling * synthetic feature weight
    Note! the synthetic feature weight is subject to l1/l2 regularization
    as all other features.
    To lessen the effect of regularization on synthetic feature weight
    (and therefore on the intercept) intercept_scaling has to be increased.

class_weight : dict or 'balanced', default=None
    Set the parameter C of class i to ``class_weight[i]*C`` for
    SVC. If not given, all classes are supposed to have
    weight one.
    The 'balanced' mode uses the values of y to automatically adjust
    weights inversely proportional to class frequencies in the input data
    as ``n_samples / (n_classes * np.bincount(y))``.

verbose : int, default=0
    Enable verbose output. Note that this setting takes advantage of a
    per-process runtime setting in liblinear that, if enabled, may not work
    properly in a multithreaded context.

random_state : int or RandomState instance, default=None
    Controls the pseudo random number generation for shuffling the data for
    the dual coordinate descent (if ``dual=True``). When ``dual=False`` the
    underlying implementation of :class:`LinearSVC` is not random and
    ``random_state`` has no effect on the results.
    Pass an int for reproducible output across multiple function calls.
    See :term:`Glossary <random_state>`.

max_iter : int, default=1000
    The maximum number of iterations to be run.

Attributes
----------
coef_ : ndarray of shape (1, n_features) if n_classes == 2             else (n_classes, n_features)
    Weights assigned to the features (coefficients in the primal
    problem). This is only available in the case of a linear kernel.

    ``coef_`` is a readonly property derived from ``raw_coef_`` that
    follows the internal memory layout of liblinear.

intercept_ : ndarray of shape (1,) if n_classes == 2 else (n_classes,)
    Constants in decision function.

classes_ : ndarray of shape (n_classes,)
    The unique classes labels.

n_iter_ : int
    Maximum number of iterations run across all classes.

See Also
--------
SVC
    Implementation of Support Vector Machine classifier using libsvm:
    the kernel can be non-linear but its SMO algorithm does not
    scale to large number of samples as LinearSVC does.

    Furthermore SVC multi-class mode is implemented using one
    vs one scheme while LinearSVC uses one vs the rest. It is
    possible to implement one vs the rest with SVC by using the
    :class:`sklearn.multiclass.OneVsRestClassifier` wrapper.

    Finally SVC can fit dense data without memory copy if the input
    is C-contiguous. Sparse data will still incur memory copy though.

sklearn.linear_model.SGDClassifier
    SGDClassifier can optimize the same cost function as LinearSVC
    by adjusting the penalty and loss parameters. In addition it requires
    less memory, allows incremental (online) learning, and implements
    various loss functions and regularization regimes.

Notes
-----
The underlying C implementation uses a random number generator to
select features when fitting the model. It is thus not uncommon
to have slightly different results for the same input data. If
that happens, try with a smaller ``tol`` parameter.

The underlying implementation, liblinear, uses a sparse internal
representation for the data that will incur a memory copy.

Predict output may not match that of standalone liblinear in certain
cases. See :ref:`differences from liblinear <liblinear_differences>`
in the narrative documentation.

References
----------
`LIBLINEAR: A Library for Large Linear Classification
<https://www.csie.ntu.edu.tw/~cjlin/liblinear/>`__

Examples
--------
>>> from sklearn.svm import LinearSVC
>>> from sklearn.pipeline import make_pipeline
>>> from sklearn.preprocessing import StandardScaler
>>> from sklearn.datasets import make_classification
>>> X, y = make_classification(n_features=4, random_state=0)
>>> clf = make_pipeline(StandardScaler(),
...                     LinearSVC(random_state=0, tol=1e-5))
>>> clf.fit(X, y)
Pipeline(steps=[('standardscaler', StandardScaler()),
                ('linearsvc', LinearSVC(random_state=0, tol=1e-05))])

>>> print(clf.named_steps['linearsvc'].coef_)
[[0.141...   0.526... 0.679... 0.493...]]

>>> print(clf.named_steps['linearsvc'].intercept_)
[0.1693...]
>>> print(clf.predict([[0, 0, 0, 0]]))
[1]
*)

val decision_function : x:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Predict confidence scores for samples.

The confidence score for a sample is the signed distance of that
sample to the hyperplane.

Parameters
----------
X : array_like or sparse matrix, shape (n_samples, n_features)
    Samples.

Returns
-------
array, shape=(n_samples,) if n_classes == 2 else (n_samples, n_classes)
    Confidence scores per (sample, class) combination. In the binary
    case, confidence score for self.classes_[1] where >0 means this
    class would be predicted.
*)

val densify : [> tag] Obj.t -> t
(**
Convert coefficient matrix to dense array format.

Converts the ``coef_`` member (back) to a numpy.ndarray. This is the
default format of ``coef_`` and is required for fitting, so calling
this method is only required on models that have previously been
sparsified; otherwise, it is a no-op.

Returns
-------
self
    Fitted estimator.
*)

val fit : ?sample_weight:[>`ArrayLike] Np.Obj.t -> x:[>`ArrayLike] Np.Obj.t -> y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> t
(**
Fit the model according to the given training data.

Parameters
----------
X : {array-like, sparse matrix} of shape (n_samples, n_features)
    Training vector, where n_samples in the number of samples and
    n_features is the number of features.

y : array-like of shape (n_samples,)
    Target vector relative to X.

sample_weight : array-like of shape (n_samples,), default=None
    Array of weights that are assigned to individual
    samples. If not provided,
    then each sample is given unit weight.

    .. versionadded:: 0.18

Returns
-------
self : object
    An instance of the estimator.
*)

val get_params : ?deep:bool -> [> tag] Obj.t -> Dict.t
(**
Get parameters for this estimator.

Parameters
----------
deep : bool, default=True
    If True, will return the parameters for this estimator and
    contained subobjects that are estimators.

Returns
-------
params : mapping of string to any
    Parameter names mapped to their values.
*)

val predict : x:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> [>`ArrayLike] Np.Obj.t
(**
Predict class labels for samples in X.

Parameters
----------
X : array_like or sparse matrix, shape (n_samples, n_features)
    Samples.

Returns
-------
C : array, shape [n_samples]
    Predicted class label per sample.
*)

val score : ?sample_weight:[>`ArrayLike] Np.Obj.t -> x:[>`ArrayLike] Np.Obj.t -> y:[>`ArrayLike] Np.Obj.t -> [> tag] Obj.t -> float
(**
Return the mean accuracy on the given test data and labels.

In multi-label classification, this is the subset accuracy
which is a harsh metric since you require for each sample that
each label set be correctly predicted.

Parameters
----------
X : array-like of shape (n_samples, n_features)
    Test samples.

y : array-like of shape (n_samples,) or (n_samples, n_outputs)
    True labels for X.

sample_weight : array-like of shape (n_samples,), default=None
    Sample weights.

Returns
-------
score : float
    Mean accuracy of self.predict(X) wrt. y.
*)

val set_params : ?params:(string * Py.Object.t) list -> [> tag] Obj.t -> t
(**
Set the parameters of this estimator.

The method works on simple estimators as well as on nested objects
(such as pipelines). The latter have parameters of the form
``<component>__<parameter>`` so that it's possible to update each
component of a nested object.

Parameters
----------
**params : dict
    Estimator parameters.

Returns
-------
self : object
    Estimator instance.
*)

val sparsify : [> tag] Obj.t -> t
(**
Convert coefficient matrix to sparse format.

Converts the ``coef_`` member to a scipy.sparse matrix, which for
L1-regularized models can be much more memory- and storage-efficient
than the usual numpy.ndarray representation.

The ``intercept_`` member is not converted.

Returns
-------
self
    Fitted estimator.

Notes
-----
For non-sparse models, i.e. when there are not many zeros in ``coef_``,
this may actually *increase* memory usage, so use this method with
care. A rule of thumb is that the number of zero elements, which can
be computed with ``(coef_ == 0).sum()``, must be more than 50% for this
to provide significant benefits.

After calling this method, further fitting with the partial_fit
method (if any) will not work until you call densify.
*)


(** Attribute coef_: get value or raise Not_found if None.*)
val coef_ : t -> [>`ArrayLike] Np.Obj.t

(** Attribute coef_: get value as an option. *)
val coef_opt : t -> ([>`ArrayLike] Np.Obj.t) option


(** Attribute intercept_: get value or raise Not_found if None.*)
val intercept_ : t -> [>`ArrayLike] Np.Obj.t

(** Attribute intercept_: get value as an option. *)
val intercept_opt : t -> ([>`ArrayLike] Np.Obj.t) option


(** Attribute classes_: get value or raise Not_found if None.*)
val classes_ : t -> [>`ArrayLike] Np.Obj.t

(** Attribute classes_: get value as an option. *)
val classes_opt : t -> ([>`ArrayLike] Np.Obj.t) option


(** Attribute n_iter_: get value or raise Not_found if None.*)
val n_iter_ : t -> int

(** Attribute n_iter_: get value as an option. *)
val n_iter_opt : t -> (int) option


(** Print the object to a human-readable representation. *)
val to_string : t -> string


(** Print the object to a human-readable representation. *)
val show : t -> string

(** Pretty-print the object to a formatter. *)
val pp : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]


end

val calibration_curve : ?normalize:bool -> ?n_bins:int -> ?strategy:[`Uniform | `Quantile] -> y_true:[>`ArrayLike] Np.Obj.t -> y_prob:[>`ArrayLike] Np.Obj.t -> unit -> ([>`ArrayLike] Np.Obj.t * [>`ArrayLike] Np.Obj.t)
(**
Compute true and predicted probabilities for a calibration curve.

The method assumes the inputs come from a binary classifier, and
discretize the [0, 1] interval into bins.

Calibration curves may also be referred to as reliability diagrams.

Read more in the :ref:`User Guide <calibration>`.

Parameters
----------
y_true : array-like of shape (n_samples,)
    True targets.

y_prob : array-like of shape (n_samples,)
    Probabilities of the positive class.

normalize : bool, default=False
    Whether y_prob needs to be normalized into the [0, 1] interval, i.e.
    is not a proper probability. If True, the smallest value in y_prob
    is linearly mapped onto 0 and the largest one onto 1.

n_bins : int, default=5
    Number of bins to discretize the [0, 1] interval. A bigger number
    requires more data. Bins with no samples (i.e. without
    corresponding values in `y_prob`) will not be returned, thus the
    returned arrays may have less than `n_bins` values.

strategy : {'uniform', 'quantile'}, default='uniform'
    Strategy used to define the widths of the bins.

    uniform
        The bins have identical widths.
    quantile
        The bins have the same number of samples and depend on `y_prob`.

Returns
-------
prob_true : ndarray of shape (n_bins,) or smaller
    The proportion of samples whose class is the positive class, in each
    bin (fraction of positives).

prob_pred : ndarray of shape (n_bins,) or smaller
    The mean predicted probability in each bin.

References
----------
Alexandru Niculescu-Mizil and Rich Caruana (2005) Predicting Good
Probabilities With Supervised Learning, in Proceedings of the 22nd
International Conference on Machine Learning (ICML).
See section 4 (Qualitative Analysis of Predictions).
*)

val check_array : ?accept_sparse:[`S of string | `StringList of string list | `Bool of bool] -> ?accept_large_sparse:bool -> ?dtype:[`S of string | `Dtype of Np.Dtype.t | `Dtypes of Np.Dtype.t list | `None] -> ?order:[`C | `F] -> ?copy:bool -> ?force_all_finite:[`Allow_nan | `Bool of bool] -> ?ensure_2d:bool -> ?allow_nd:bool -> ?ensure_min_samples:int -> ?ensure_min_features:int -> ?estimator:[>`BaseEstimator] Np.Obj.t -> array:Py.Object.t -> unit -> Py.Object.t
(**
Input validation on an array, list, sparse matrix or similar.

By default, the input is checked to be a non-empty 2D array containing
only finite values. If the dtype of the array is object, attempt
converting to float, raising on failure.

Parameters
----------
array : object
    Input object to check / convert.

accept_sparse : string, boolean or list/tuple of strings (default=False)
    String[s] representing allowed sparse matrix formats, such as 'csc',
    'csr', etc. If the input is sparse but not in the allowed format,
    it will be converted to the first listed format. True allows the input
    to be any format. False means that a sparse matrix input will
    raise an error.

accept_large_sparse : bool (default=True)
    If a CSR, CSC, COO or BSR sparse matrix is supplied and accepted by
    accept_sparse, accept_large_sparse=False will cause it to be accepted
    only if its indices are stored with a 32-bit dtype.

    .. versionadded:: 0.20

dtype : string, type, list of types or None (default='numeric')
    Data type of result. If None, the dtype of the input is preserved.
    If 'numeric', dtype is preserved unless array.dtype is object.
    If dtype is a list of types, conversion on the first type is only
    performed if the dtype of the input is not in the list.

order : 'F', 'C' or None (default=None)
    Whether an array will be forced to be fortran or c-style.
    When order is None (default), then if copy=False, nothing is ensured
    about the memory layout of the output array; otherwise (copy=True)
    the memory layout of the returned array is kept as close as possible
    to the original array.

copy : boolean (default=False)
    Whether a forced copy will be triggered. If copy=False, a copy might
    be triggered by a conversion.

force_all_finite : boolean or 'allow-nan', (default=True)
    Whether to raise an error on np.inf, np.nan, pd.NA in array. The
    possibilities are:

    - True: Force all values of array to be finite.
    - False: accepts np.inf, np.nan, pd.NA in array.
    - 'allow-nan': accepts only np.nan and pd.NA values in array. Values
      cannot be infinite.

    .. versionadded:: 0.20
       ``force_all_finite`` accepts the string ``'allow-nan'``.

    .. versionchanged:: 0.23
       Accepts `pd.NA` and converts it into `np.nan`

ensure_2d : boolean (default=True)
    Whether to raise a value error if array is not 2D.

allow_nd : boolean (default=False)
    Whether to allow array.ndim > 2.

ensure_min_samples : int (default=1)
    Make sure that the array has a minimum number of samples in its first
    axis (rows for a 2D array). Setting to 0 disables this check.

ensure_min_features : int (default=1)
    Make sure that the 2D array has some minimum number of features
    (columns). The default value of 1 rejects empty datasets.
    This check is only enforced when the input data has effectively 2
    dimensions or is originally 1D and ``ensure_2d`` is True. Setting to 0
    disables this check.

estimator : str or estimator instance (default=None)
    If passed, include the name of the estimator in warning messages.

Returns
-------
array_converted : object
    The converted and validated array.
*)

val check_consistent_length : Py.Object.t list -> Py.Object.t
(**
Check that all arrays have consistent first dimensions.

Checks whether all objects in arrays have the same shape or length.

Parameters
----------
*arrays : list or tuple of input objects.
    Objects that will be checked for consistent length.
*)

val check_cv : ?cv:[`BaseCrossValidator of [>`BaseCrossValidator] Np.Obj.t | `Arr of [>`ArrayLike] Np.Obj.t | `I of int] -> ?y:[>`ArrayLike] Np.Obj.t -> ?classifier:bool -> unit -> [`BaseCrossValidator|`Object] Np.Obj.t
(**
Input checker utility for building a cross-validator

Parameters
----------
cv : int, cross-validation generator or an iterable, default=None
    Determines the cross-validation splitting strategy.
    Possible inputs for cv are:
    - None, to use the default 5-fold cross validation,
    - integer, to specify the number of folds.
    - :term:`CV splitter`,
    - An iterable yielding (train, test) splits as arrays of indices.

    For integer/None inputs, if classifier is True and ``y`` is either
    binary or multiclass, :class:`StratifiedKFold` is used. In all other
    cases, :class:`KFold` is used.

    Refer :ref:`User Guide <cross_validation>` for the various
    cross-validation strategies that can be used here.

    .. versionchanged:: 0.22
        ``cv`` default value changed from 3-fold to 5-fold.

y : array-like, default=None
    The target variable for supervised learning problems.

classifier : bool, default=False
    Whether the task is a classification task, in which case
    stratified KFold will be used.

Returns
-------
checked_cv : a cross-validator instance.
    The return value is a cross-validator which generates the train/test
    splits via the ``split`` method.
*)

val check_is_fitted : ?attributes:[`S of string | `StringList of string list | `Arr of [>`ArrayLike] Np.Obj.t] -> ?msg:string -> ?all_or_any:[`Callable of Py.Object.t | `PyObject of Py.Object.t] -> estimator:[>`BaseEstimator] Np.Obj.t -> unit -> Py.Object.t
(**
Perform is_fitted validation for estimator.

Checks if the estimator is fitted by verifying the presence of
fitted attributes (ending with a trailing underscore) and otherwise
raises a NotFittedError with the given message.

This utility is meant to be used internally by estimators themselves,
typically in their own predict / transform methods.

Parameters
----------
estimator : estimator instance.
    estimator instance for which the check is performed.

attributes : str, list or tuple of str, default=None
    Attribute name(s) given as string or a list/tuple of strings
    Eg.: ``['coef_', 'estimator_', ...], 'coef_'``

    If `None`, `estimator` is considered fitted if there exist an
    attribute that ends with a underscore and does not start with double
    underscore.

msg : string
    The default error message is, 'This %(name)s instance is not fitted
    yet. Call 'fit' with appropriate arguments before using this
    estimator.'

    For custom messages if '%(name)s' is present in the message string,
    it is substituted for the estimator name.

    Eg. : 'Estimator, %(name)s, must be fitted before sparsifying'.

all_or_any : callable, {all, any}, default all
    Specify whether all or any of the given attributes must exist.

Returns
-------
None

Raises
------
NotFittedError
    If the attributes are not found.
*)

val clone : ?safe:bool -> estimator:[>`BaseEstimator] Np.Obj.t -> unit -> Py.Object.t
(**
Constructs a new estimator with the same parameters.

Clone does a deep copy of the model in an estimator
without actually copying attached data. It yields a new estimator
with the same parameters that has not been fit on any data.

Parameters
----------
estimator : {list, tuple, set} of estimator objects or estimator object
    The estimator or group of estimators to be cloned.

safe : bool, default=True
    If safe is false, clone will fall back to a deep copy on objects
    that are not estimators.
*)

val column_or_1d : ?warn:bool -> y:[>`ArrayLike] Np.Obj.t -> unit -> [>`ArrayLike] Np.Obj.t
(**
Ravel column or 1d numpy array, else raises an error

Parameters
----------
y : array-like

warn : boolean, default False
   To control display of warnings.

Returns
-------
y : array
*)

val expit : ?out:Py.Object.t -> ?where:Py.Object.t -> x:[>`ArrayLike] Np.Obj.t -> unit -> [>`ArrayLike] Np.Obj.t
(**
expit(x, /, out=None, *, where=True, casting='same_kind', order='K', dtype=None, subok=True[, signature, extobj])

expit(x)

Expit (a.k.a. logistic sigmoid) ufunc for ndarrays.

The expit function, also known as the logistic sigmoid function, is
defined as ``expit(x) = 1/(1+exp(-x))``.  It is the inverse of the
logit function.

Parameters
----------
x : ndarray
    The ndarray to apply expit to element-wise.

Returns
-------
out : ndarray
    An ndarray of the same shape as x. Its entries
    are `expit` of the corresponding entry of x.

See Also
--------
logit

Notes
-----
As a ufunc expit takes a number of optional
keyword arguments. For more information
see `ufuncs <https://docs.scipy.org/doc/numpy/reference/ufuncs.html>`_

.. versionadded:: 0.10.0

Examples
--------
>>> from scipy.special import expit, logit

>>> expit([-np.inf, -1.5, 0, 1.5, np.inf])
array([ 0.        ,  0.18242552,  0.5       ,  0.81757448,  1.        ])

`logit` is the inverse of `expit`:

>>> logit(expit([-2.5, 0, 3.1, 5.0]))
array([-2.5,  0. ,  3.1,  5. ])

Plot expit(x) for x in [-6, 6]:

>>> import matplotlib.pyplot as plt
>>> x = np.linspace(-6, 6, 121)
>>> y = expit(x)
>>> plt.plot(x, y)
>>> plt.grid()
>>> plt.xlim(-6, 6)
>>> plt.xlabel('x')
>>> plt.title('expit(x)')
>>> plt.show()
*)

val fmin_bfgs : ?fprime:Py.Object.t -> ?args:Py.Object.t -> ?gtol:float -> ?norm:float -> ?epsilon:[`Arr of [>`ArrayLike] Np.Obj.t | `I of int] -> ?maxiter:int -> ?full_output:bool -> ?disp:bool -> ?retall:bool -> ?callback:Py.Object.t -> f:Py.Object.t -> x0:[>`ArrayLike] Np.Obj.t -> unit -> ([>`ArrayLike] Np.Obj.t * float * [>`ArrayLike] Np.Obj.t * [>`ArrayLike] Np.Obj.t * int * int * int * [>`ArrayLike] Np.Obj.t)
(**
Minimize a function using the BFGS algorithm.

Parameters
----------
f : callable f(x,*args)
    Objective function to be minimized.
x0 : ndarray
    Initial guess.
fprime : callable f'(x,*args), optional
    Gradient of f.
args : tuple, optional
    Extra arguments passed to f and fprime.
gtol : float, optional
    Gradient norm must be less than gtol before successful termination.
norm : float, optional
    Order of norm (Inf is max, -Inf is min)
epsilon : int or ndarray, optional
    If fprime is approximated, use this value for the step size.
callback : callable, optional
    An optional user-supplied function to call after each
    iteration. Called as callback(xk), where xk is the
    current parameter vector.
maxiter : int, optional
    Maximum number of iterations to perform.
full_output : bool, optional
    If True,return fopt, func_calls, grad_calls, and warnflag
    in addition to xopt.
disp : bool, optional
    Print convergence message if True.
retall : bool, optional
    Return a list of results at each iteration if True.

Returns
-------
xopt : ndarray
    Parameters which minimize f, i.e., f(xopt) == fopt.
fopt : float
    Minimum value.
gopt : ndarray
    Value of gradient at minimum, f'(xopt), which should be near 0.
Bopt : ndarray
    Value of 1/f''(xopt), i.e., the inverse Hessian matrix.
func_calls : int
    Number of function_calls made.
grad_calls : int
    Number of gradient calls made.
warnflag : integer
    1 : Maximum number of iterations exceeded.
    2 : Gradient and/or function calls not changing.
    3 : NaN result encountered.
allvecs  :  list
    The value of xopt at each iteration. Only returned if retall is True.

See also
--------
minimize: Interface to minimization algorithms for multivariate
    functions. See the 'BFGS' `method` in particular.

Notes
-----
Optimize the function, f, whose gradient is given by fprime
using the quasi-Newton method of Broyden, Fletcher, Goldfarb,
and Shanno (BFGS)

References
----------
Wright, and Nocedal 'Numerical Optimization', 1999, p. 198.
*)

val indexable : Py.Object.t list -> Py.Object.t
(**
Make arrays indexable for cross-validation.

Checks consistent length, passes through None, and ensures that everything
can be indexed by converting sparse matrices to csr and converting
non-interable objects to arrays.

Parameters
----------
*iterables : lists, dataframes, arrays, sparse matrices
    List of objects to ensure sliceability.
*)

val label_binarize : ?neg_label:int -> ?pos_label:int -> ?sparse_output:bool -> y:[>`ArrayLike] Np.Obj.t -> classes:[>`ArrayLike] Np.Obj.t -> unit -> [>`ArrayLike] Np.Obj.t
(**
Binarize labels in a one-vs-all fashion

Several regression and binary classification algorithms are
available in scikit-learn. A simple way to extend these algorithms
to the multi-class classification case is to use the so-called
one-vs-all scheme.

This function makes it possible to compute this transformation for a
fixed set of class labels known ahead of time.

Parameters
----------
y : array-like
    Sequence of integer labels or multilabel data to encode.

classes : array-like of shape [n_classes]
    Uniquely holds the label for each class.

neg_label : int (default: 0)
    Value with which negative labels must be encoded.

pos_label : int (default: 1)
    Value with which positive labels must be encoded.

sparse_output : boolean (default: False),
    Set to true if output binary array is desired in CSR sparse format

Returns
-------
Y : numpy array or CSR matrix of shape [n_samples, n_classes]
    Shape will be [n_samples, 1] for binary problems.

Examples
--------
>>> from sklearn.preprocessing import label_binarize
>>> label_binarize([1, 6], classes=[1, 2, 4, 6])
array([[1, 0, 0, 0],
       [0, 0, 0, 1]])

The class ordering is preserved:

>>> label_binarize([1, 6], classes=[1, 6, 4, 2])
array([[1, 0, 0, 0],
       [0, 1, 0, 0]])

Binary targets transform to a column vector

>>> label_binarize(['yes', 'no', 'no', 'yes'], classes=['no', 'yes'])
array([[1],
       [0],
       [0],
       [1]])

See also
--------
LabelBinarizer : class used to wrap the functionality of label_binarize and
    allow for fitting to classes independently of the transform operation
*)

val signature : ?follow_wrapped:Py.Object.t -> obj:Py.Object.t -> unit -> Py.Object.t
(**
Get a signature object for the passed callable.
*)

val xlogy : ?out:Py.Object.t -> ?where:Py.Object.t -> x:[>`ArrayLike] Np.Obj.t -> unit -> [>`ArrayLike] Np.Obj.t
(**
xlogy(x1, x2, /, out=None, *, where=True, casting='same_kind', order='K', dtype=None, subok=True[, signature, extobj])

xlogy(x, y)

Compute ``x*log(y)`` so that the result is 0 if ``x = 0``.

Parameters
----------
x : array_like
    Multiplier
y : array_like
    Argument

Returns
-------
z : array_like
    Computed x*log(y)

Notes
-----

.. versionadded:: 0.13.0
*)

