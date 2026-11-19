{% docs ref__survey_question_option %}
The answer options of every survey question, one row per option, as the Tamanu app
shows them on the form. Use it to check that the categories a dashboard or report groups
survey answers into still cover every option a form offers. Questions without a list of
options, such as free text, numbers and Yes/No questions, do not appear.
{% enddocs %}

{% docs ref__survey_question_option__survey_screen_component_id %}
Identifier of the question as it appears on this survey.
{% enddocs %}

{% docs ref__survey_question_option__survey_visibility_status %}
Visibility status of the survey. `historical` marks a survey that is no longer offered.
{% enddocs %}

{% docs ref__survey_question_option__question_visibility_status %}
Visibility status of the question on this survey. `historical` marks a question that is no
longer shown.
{% enddocs %}

{% docs ref__survey_question_option__data_element_id %}
Identifier of the data element the question's answers are stored against.
{% enddocs %}

{% docs ref__survey_question_option__question_text %}
The question as shown on the form.
{% enddocs %}

{% docs ref__survey_question_option__question_type %}
Type of the question, such as `Select`, `Radio` or `MultiSelect`.
{% enddocs %}

{% docs ref__survey_question_option__options_source %}
Where the options come from: `question` when this survey sets its own options for the
question, `data_element` when it uses the question's default options.
{% enddocs %}

{% docs ref__survey_question_option__option_index %}
Position of the option in the list shown on the form, starting at 1.
{% enddocs %}

{% docs ref__survey_question_option__option_label %}
The answer option as shown on the form. This is also the value recorded as the answer
when it is chosen.
{% enddocs %}
